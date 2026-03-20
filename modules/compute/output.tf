# Clés privées SSH générées pour chaque VM (à récupérer via terraform output -raw)
output "private_keys" {
  value     = { for k, v in tls_private_key.vm_key : k => v.private_key_pem }
  sensitive = true
}

# IDs des instances créées (utile pour le monitoring ou l'inventaire Ansible)
output "instance_ids" {
  value = { for k, v in openstack_compute_instance_v2.vm : k => v.id }
}

# Noms des keypairs créées sur OpenStack
output "keypair_names" {
  value = { for k, kp in openstack_compute_keypair_v2.vm_kp : k => kp.name }
}

# Liste des ports réseaux créés avec leurs IPs respectives
output "vm_network_details" {
  value = {
    for k, p in openstack_networking_port_v2.vm_ports : k => {
      ip_address = length(p.all_fixed_ips) > 0 ? p.all_fixed_ips[0] : null
      network_id = p.network_id
    }
  }
}
