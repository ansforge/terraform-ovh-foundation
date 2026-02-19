ovh_project_id  = "a5a3658023e146e78a22afd04601b813"
os_auth_url     = "https://auth.cloud.ovh.net/v3/"
os_project_name = "a5a3658023e146e78a22afd04601b813"
user_name       = "a817b4470bcd42b0af4dd9ab40c550df" 
os_user         = "5322855a312548738bfcc487c3a17cdd"
os_password     = "quOw_e1ov11pyQrNbV_w-zAcA42zOq854kQac0I5Ct1DcvPhkeTh2aazqh8GJh8YHRzVeySXSMyb7IuImBaOXw"
os_domain      = "Default"
region         = "SBG5"

vms = {
  tfansible = {
    name          = "infra-amont-tfansible01"
    flavor_id     = "fd6bdb12-606e-4dea-a0b7-c4baf07f5e19"
    image_id      = "61a6cfe8-6f70-4a55-9929-f95a7d02c26b"
    key_name      = "vm-tfansible-key"
    public_ip     = true
    extra_disk_gb = 0
    networks      = [{ name = "amont-outillage-lan", ip = null, enabled = true }]
    tags          = { Owner = "infra-team", Env = "amont", App = "ansible", Lot = "01" }
  }

  proxy = {
    name          = "infra-amont-proxy01"
    flavor_id     = "fd6bdb12-606e-4dea-a0b7-c4baf07f5e19"
    image_id      = "61a6cfe8-6f70-4a55-9929-f95a7d02c26b"
    key_name      = "vm-proxy-key"
    public_ip     = true
    extra_disk_gb = 50
    networks      = [
      { name = "amont-outillage-lan", ip = null, enabled = true },
      { name = "fwfe-amont-tech-172.16.41.0-24", ip = "172.16.41.100", enabled = true }
    ]
    tags          = { Owner = "infra-team", Env = "amont", App = "squid", Lot = "01" }
  }

  repo = {
    name          = "infra-amont-repo01"
    flavor_id     = "fd6bdb12-606e-4dea-a0b7-c4baf07f5e19"
    image_id      = "61a6cfe8-6f70-4a55-9929-f95a7d02c26b"
    key_name      = "vm-repo-key"
    public_ip     = true
    extra_disk_gb = 150
    networks      = [{ name = "amont-outillage-lan", ip = null, enabled = true }]
    tags          = { Owner = "infra-team", Env = "amont", App = "repo", Lot = "01" }
  }

  rebond = {
    name          = "infra-amont-rebond01"
    flavor_id     = "fd6bdb12-606e-4dea-a0b7-c4baf07f5e19"
    image_id      = "61a6cfe8-6f70-4a55-9929-f95a7d02c26b"
    key_name      = "vm-rebond-key"
    public_ip     = true
    extra_disk_gb = 0
    networks      = [
      { name = "amont-outillage-lan", ip = null, enabled = true },
      { name = "fwfe-amont-admin-172.16.11.0-24", ip = "172.16.11.100", enabled = true }
    ]
    tags          = { Owner = "infra-team", Env = "amont", App = "rebond", Lot = "01" }
  }

   dns = {
     name          = "infra-amont-dns01"
     flavor_id     = "fd6bdb12-606e-4dea-a0b7-c4baf07f5e19"
     image_id      = "5bcb6f1f-22a9-4bbe-9693-254c4572048f"
     key_name      = "vm-dns-key"
     public_ip     = true
     extra_disk_gb = 0
     networks      = [{ name = "amont-outillage-lan", ip = null, enabled = true }]
     tags          = { Owner = "infra-team", Env = "amont", App = "dns", Lot = "01" }
     skip_key_creation = true
   }
 }
