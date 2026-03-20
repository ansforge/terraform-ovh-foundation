
terraform {
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack" }
    tls       = { source = "hashicorp/tls" }
  }
}

# 1. Génération des clés SSH
resource "tls_private_key" "vm_key" {
  for_each  = var.vms
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "vm_kp" {
  for_each   = var.vms
  name       = each.value.key_name
  public_key = tls_private_key.vm_key[each.key].public_key_openssh
}

# 2. Recherche des IDs de réseaux
data "openstack_networking_network_v2" "networks" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for net in vm_cfg.networks : net.name => net
    }
  ]...)
  name = each.key
}

# 3. Création des Ports avec IPs fixes
resource "openstack_networking_port_v2" "vm_ports" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for idx, net in vm_cfg.networks : "${vm_key}_${idx}" => {
        vm_name  = vm_key
        net_name = net.name
        ip       = net.ip
        enabled  = net.enabled
      }
    }
  ]...)

  name                  = "port-${each.value.vm_name}-${each.value.net_name}"
  network_id            = data.openstack_networking_network_v2.networks[each.value.net_name].id
  admin_state_up        = "true"
  port_security_enabled = false
  security_group_ids    = []

  fixed_ip {
    ip_address = each.value.ip
  }
}

# 4. Création des Instances
resource "openstack_compute_instance_v2" "vm" {
  for_each     = var.vms
  name         = each.value.name
  image_id     = each.value.image_id
  flavor_id    = each.value.flavor_id
  key_pair     = openstack_compute_keypair_v2.vm_kp[each.key].name
  region       = var.region
  config_drive = true

  # Cloud-init minimal pour l'utilisateur et le hostname
  user_data = <<-EOF
    #!/bin/bash
    useradd -m -s /bin/bash admin
    echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
    hostnamectl set-hostname ${each.value.name}
  EOF

  # Interface primaire (Index 0)
  network {
    port = openstack_networking_port_v2.vm_ports["${each.key}_0"].id
  }

  # Interfaces secondaires
  dynamic "network" {
    for_each = {
      for idx, net in slice(each.value.networks, 1, length(each.value.networks)) :
      idx => net if net.enabled
    }
    content {
      port = openstack_networking_port_v2.vm_ports["${each.key}_${network.key + 1}"].id
    }
  }

  metadata = each.value.tags
}

# 5. Volumes additionnels
resource "openstack_blockstorage_volume_v3" "extra_disk" {
  for_each = { for k, v in var.vms : k => v if v.extra_disk_gb > 0 }
  name     = "${each.value.name}-extra"
  size     = each.value.extra_disk_gb
  region   = var.region
}

resource "openstack_compute_volume_attach_v2" "attach_extra" {
  for_each    = { for k, v in var.vms : k => v if v.extra_disk_gb > 0 }
  instance_id = openstack_compute_instance_v2.vm[each.key].id
  volume_id   = openstack_blockstorage_volume_v3.extra_disk[each.key].id
}
