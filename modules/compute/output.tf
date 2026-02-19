output "keypair_names" {
  value = { for k, kp in openstack_compute_keypair_v2.vm_kp : k => kp.name }
}
