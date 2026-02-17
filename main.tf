# --- terraform-ovh-foundation/main.tf (Racine) ---

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

provider "openstack" {
  auth_url                        = var.os_auth_url
  application_credential_id       = var.os_user
  application_credential_secret   = var.os_password
  region                          = var.region
}

provider "ovh" {
  endpoint            = var.ovh_endpoint
  application_key     = var.ovh_application_key
  application_secret  = var.ovh_application_secret
  consumer_key        = var.ovh_consumer_key
}

# --- MODIFICATION ICI : La source pointe vers le dossier local ---
module "instances" {
  source       = "git::https://github.com/ansforge/terraform-ovh-foundation.git//modules/compute?ref=amont"

  vms            = var.vms
  region         = var.region
  ovh_project_id = var.ovh_project_id
}
# -----------------------------------------------------------------

output "private_keys" {
  value     = module.instances.private_keys
  sensitive = true
}
