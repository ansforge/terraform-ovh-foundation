ovh_project_id = "51b48fc072e34415922eb448c8121677"
region         = "EU-WEST-PAR"

vms = {
  tfansible = {
    name          = "infra-outils-tfansible01"
    flavor_id     = "1d6ae309-12da-4011-9169-56e4a3159e5e"
    image_id      = "4db92e15-38a0-4e25-8290-549bb81e34e5"
    key_name      = "vm-tfansible-key"
    extra_disk_gb = 0
    networks = [
      { name = "Ext-Net", ip = "", enabled = true },
      { name = "outils-infra-app-10.16.90.0-24", ip = "10.16.90.14", enabled = true }
    ]
    tags = { Owner = "infra-team", Env = "outils", App = "ansible" }
  }

  proxy = {
    name          = "infra-outils-proxy01"
    flavor_id     = "1d6ae309-12da-4011-9169-56e4a3159e5e"
    image_id      = "4db92e15-38a0-4e25-8290-549bb81e34e5"
    key_name      = "vm-proxy-key"
    extra_disk_gb = 50
    networks = [
      { name = "outils-dmz-exposed-10.15.30.0-24", ip = "10.15.30.11", enabled = true },
      { name = "outils-dmz-transit-10.16.70.0-24", ip = "10.16.70.11", enabled = true },
      { name = "outils-dmz-admin-10.16.52.0-24", ip   = "10.16.52.11", enabled = true },
    ]
    tags = { Owner = "infra-team", Env = "outils", App = "proxy" }
  }

  repo = {
    name          = "infra-outils-repo01"
    flavor_id     = "1d6ae309-12da-4011-9169-56e4a3159e5e"
    image_id      = "4db92e15-38a0-4e25-8290-549bb81e34e5"
    key_name      = "vm-repo-key"
    extra_disk_gb = 150
    networks = [{ name = "outils-infra-app-10.16.90.0-24", ip = "10.16.90.12", enabled = true }]
    tags = { Owner = "infra-team", Env = "outils", App = "repo" }
  }

  freeipa = {
    name          = "infra-outils-freeipa01"
    flavor_id     = "1d6ae309-12da-4011-9169-56e4a3159e5e"
    image_id      = "4db92e15-38a0-4e25-8290-549bb81e34e5"
    key_name      = "vm-freeipa-key"
    extra_disk_gb = 0
    networks = [{ name = "outils-infra-app-10.16.90.0-24", ip = "10.16.90.13", enabled = true }]
    tags = { Owner = "infra-team", Env = "outils", App = "freeipa" }
  }
}
