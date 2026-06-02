ovh_project_id = "a5a3658023e146e78a22afd04601b813"
region         = "SBG5"

vms = {
  tfansible = {
    name          = "infra-amont-tfansible01"
    flavor_id     = "acb62e0d-fa78-4a09-8e08-ba2e30fb4ff9"
    image_id      = "09189822-26b4-4407-87c3-2b2957588d53"
    key_name      = "vm-tfansible-key"
    extra_disk_gb = 0
    networks      = [
      { name = "Ext-Net", ip = "", enabled = true },
      { name = "preprod-amont-infra-app-10.12.90.0-24", ip = "10.12.90.14", enabled = true }
    ]
    tags          = { Owner = "infra-team", Env = "amont", App = "ansible" }
  }

proxy = {
  name          = "infra-amont-proxy01"
  flavor_id     = "acb62e0d-fa78-4a09-8e08-ba2e30fb4ff9"
  image_id      = "09189822-26b4-4407-87c3-2b2957588d53"
  key_name      = "vm-proxy-key"
  extra_disk_gb = 50
  networks = [
    { name = "preprod-amont-dmz-exposed-10.12.30.0-24", ip = "10.12.30.11", enabled = true },
    { name = "preprod-amont-dmz-transit-10.12.70.0-24", ip = "10.12.70.11", enabled = true },
    { name = "preprod-amont-dmz-admin-10.12.52.0-24", ip = "10.12.52.11", enabled = true },
  ]
  tags          = { Owner = "infra-team", Env = "amont", App = "proxy" }

}

  repo = {
    name          = "infra-amont-repo01"
    flavor_id     = "acb62e0d-fa78-4a09-8e08-ba2e30fb4ff9"
    image_id      = "09189822-26b4-4407-87c3-2b2957588d53"
    key_name      = "vm-repo-key"
    extra_disk_gb = 150
    networks      = [{ name = "preprod-amont-infra-app-10.12.90.0-24", ip = "10.12.90.12", enabled = true }]
    tags          = { Owner = "infra-team", Env = "amont", App = "repo" }
  }

  freeipa = {
    name          = "infra-amont-freeipa01"
    flavor_id     = "acb62e0d-fa78-4a09-8e08-ba2e30fb4ff9"
    image_id      = "09189822-26b4-4407-87c3-2b2957588d53"
    key_name      = "vm-freeipa-key"
    extra_disk_gb = 0
    networks      = [{ name = "preprod-amont-infra-app-10.12.90.0-24", ip = "10.12.90.13", enabled = true }]
    tags          = { Owner = "infra-team", Env = "amont", App = "freeipa" }
  }
}
