terraform {
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack" }
    tls       = { source = "hashicorp/tls" }
  }
}

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

data "openstack_networking_network_v2" "networks" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for net in vm_cfg.networks : net.name => net if net.name != "Ext-Net"
    }
  ]...)
  name = each.key
}

resource "openstack_networking_port_v2" "vm_ports" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for idx, net in vm_cfg.networks : "${vm_key}_${idx}" => {
        vm_name  = vm_key
        net_name = net.name
        ip       = net.ip
      } if net.name != "Ext-Net"
    }
  ]...)

  name                  = "port-${each.value.vm_name}-${each.value.net_name}"
  network_id            = data.openstack_networking_network_v2.networks[each.value.net_name].id
  admin_state_up        = "true"
  port_security_enabled = false

  fixed_ip {
    ip_address = each.value.ip
  }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each     = var.vms
  name         = each.value.name
  image_id     = each.value.image_id
  flavor_id    = each.value.flavor_id
  key_pair     = openstack_compute_keypair_v2.vm_kp[each.key].name
  region       = var.region
  config_drive = true

  user_data = <<-EOF
    #!/bin/bash
    useradd -m -s /bin/bash admin
    echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
    hostnamectl set-hostname ${each.value.name}
    
    sleep 15
    IFACE_PRIV=$(ip -o addr show | grep "10.11.90" | awk '{print $2}')
    if [ ! -z "$IFACE_PRIV" ]; then
      nmcli connection modify "System $IFACE_PRIV" ipv4.never-default yes ipv4.route-metric 200
      nmcli connection up "System $IFACE_PRIV"
    fi
  EOF

  dynamic "network" {
    for_each = { for idx, net in each.value.networks : idx => net }
    content {
      name = network.value.name == "Ext-Net" ? "Ext-Net" : null
      port = network.value.name != "Ext-Net" ? openstack_networking_port_v2.vm_ports["${each.key}_${network.key}"].id : null
    }
  }

  metadata = each.value.tags
}

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
