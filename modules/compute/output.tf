
output "instance_ids" {
  description = "IDs des instances OpenStack"
  value       = { for k, v in openstack_compute_instance_v2.vm : k => v.id }
}

# On renvoie les adresses IP de chaque port créé
output "instance_ips" {
  description = "Adresses IP fixées pour chaque interface de VM"
  value = {
    for key, port in openstack_networking_port_v2.vm_ports : key => port.all_fixed_ips[0]
  }
}



output "private_keys" {
  value     = { for k, v in tls_private_key.vm_key : k => v.private_key_pem }
  sensitive = true
}
