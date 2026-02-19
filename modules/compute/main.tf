terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 3.4.0"
    }
    ovh = {
      source  = "ovh/ovh"
      version = ">= 0.35.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.2.0"
    }
  }
}

# Génération des clés uniquement pour les VMs qui n'ont pas de clé existante
resource "tls_private_key" "vm_key" {
  for_each  = { for k, v in var.vms : k => v if !lookup(v, "skip_key_creation", false) }
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Création des keypairs OpenStack uniquement pour les VMs qui n'ont pas de clé existante
resource "openstack_compute_keypair_v2" "vm_kp" {
  for_each   = { for k, v in var.vms : k => v if !lookup(v, "skip_key_creation", false) }
  name       = each.value.key_name
  public_key = tls_private_key.vm_key[each.key].public_key_openssh
}

# Création des instances
resource "openstack_compute_instance_v2" "vm" {
  for_each  = var.vms
  name      = each.value.name
  image_id  = each.value.image_id
  flavor_id = each.value.flavor_id
  key_pair  = each.value.key_name  # Réutilise la clé existante si skip_key_creation = true
  region    = var.region

  network {
    name        = each.value.networks[0].name
    fixed_ip_v4 = each.value.networks[0].ip
  }

  metadata = each.value.tags
}

# Réseaux secondaires
data "openstack_networking_network_v2" "secondary_nets" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for idx, net in vm_cfg.networks : "${vm_key}_${idx}" => net
      if idx > 0 && net.enabled
    }
  ]...)
  name = each.value.name
}

resource "openstack_compute_interface_attach_v2" "secondary_attach" {
  for_each = merge([
    for vm_key, vm_cfg in var.vms : {
      for idx, net in vm_cfg.networks : "${vm_key}_${idx}" => {
        vm_id = openstack_compute_instance_v2.vm[vm_key].id
        net_name = net.name
        fixed_ip = net.ip
      }
      if idx > 0 && net.enabled
    }
  ]...)

  instance_id = each.value.vm_id
  network_id  = data.openstack_networking_network_v2.secondary_nets[each.key].id
  fixed_ip    = each.value.fixed_ip
}

# Disques additionnels
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

# Réseaux principaux
data "openstack_networking_network_v2" "outillage_net" {
  name = var.vms["tfansible"].networks[0].name
}

data "openstack_networking_subnet_v2" "outillage_subnet" {
  network_id = data.openstack_networking_network_v2.outillage_net.id
}

# Gateways OVH
resource "ovh_cloud_project_gateway" "gateway_outillage" {
  service_name = var.ovh_project_id
  name         = "gateway-amont-outillage"
  model        = "s"
  region       = var.region
  network_id   = data.openstack_networking_network_v2.outillage_net.id
  subnet_id    = data.openstack_networking_subnet_v2.outillage_subnet.id
}

data "openstack_networking_network_v2" "tech_net" {
  name = "fwfe-amont-tech-172.16.41.0-24"
}

data "openstack_networking_subnet_v2" "tech_subnet" {
  network_id = data.openstack_networking_network_v2.tech_net.id
}

resource "ovh_cloud_project_gateway" "gateway_tech" {
  service_name = var.ovh_project_id
  name         = "gateway-amont-tech"
  model        = "s"
  region       = var.region
  network_id   = data.openstack_networking_network_v2.tech_net.id
  subnet_id    = data.openstack_networking_subnet_v2.tech_subnet.id
}

# Output des clés privées (seulement pour les clés gérées par Terraform)
output "private_keys" {
  value     = { for k, v in tls_private_key.vm_key : k => v.private_key_pem }
  sensitive = true
}
