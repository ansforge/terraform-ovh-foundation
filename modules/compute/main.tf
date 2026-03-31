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

  lifecycle {
    ignore_changes = all
  }
}

resource "openstack_compute_keypair_v2" "vm_kp" {
  for_each   = var.vms
  name       = "vm-${each.key}-key"
  public_key = tls_private_key.vm_key[each.key].public_key_openssh

  lifecycle {
    ignore_changes = all
  }
}

data "openstack_networking_network_v2" "networks" {
  for_each = toset(distinct(flatten([
    for vm in var.vms : [for net in vm.networks : net.name]
  ])))

  name = each.value
}

data "openstack_networking_subnet_v2" "subnets" {
  for_each   = { for k, v in data.openstack_networking_network_v2.networks : k => v if k != "Ext-Net" }
  network_id = each.value.id
}

resource "openstack_networking_port_v2" "vm_ports" {
  for_each = {
    for pair in flatten([
      for vm_key, vm_val in var.vms : [
        for net in vm_val.networks : {
          vm_key   = vm_key
          net_name = net.name
          ip       = net.ip
        }
      ]
    ]) : "${pair.vm_key}_${pair.net_name}" => pair if pair.net_name != "Ext-Net"
  }

  name                  = "port-${each.value.vm_key}-${each.value.net_name}"
  network_id            = data.openstack_networking_network_v2.networks[each.value.net_name].id
  admin_state_up        = true
  port_security_enabled = false

  dynamic "fixed_ip" {
    for_each = each.value.ip != "" ? [1] : []
    content {
      ip_address = each.value.ip
      subnet_id  = data.openstack_networking_subnet_v2.subnets[each.value.net_name].id
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each = var.vms

  name      = each.value.name
  image_id  = each.value.image_id
  flavor_id = each.value.flavor_id
  key_pair  = openstack_compute_keypair_v2.vm_kp[each.key].name

  metadata = each.value.tags

  dynamic "network" {
    for_each = each.value.networks
    content {
      name = network.value.name == "Ext-Net" ? "Ext-Net" : null
      port = network.value.name != "Ext-Net" ? openstack_networking_port_v2.vm_ports["${each.key}_${network.value.name}"].id : null
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      user_data,
      network,
      key_pair,
      image_id,
      flavor_id,
      metadata,
      security_groups
    ]
  }
}

resource "openstack_blockstorage_volume_v3" "extra_disk" {
  for_each = { for k, v in var.vms : k => v if v.extra_disk_gb > 0 }

  name = "infra-prod-${each.key}-extra"
  size = each.value.extra_disk_gb

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

resource "openstack_compute_volume_attach_v2" "attach_extra" {
  for_each = openstack_blockstorage_volume_v3.extra_disk

  instance_id = openstack_compute_instance_v2.vm[each.key].id
  volume_id   = each.value.id

  lifecycle {
    ignore_changes = all
  }
}
