terraform {
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack", version = ">= 1.53.0" }
    ovh       = { source = "ovh/ovh", version = ">= 0.40.0" }
    vault     = { source = "hashicorp/vault", version = ">= 3.25.0" }
  }
}

provider "vault" { skip_child_token = true }

ephemeral "vault_kv_secret_v2" "os" {
  mount = "iacrunner-prod"
  name  = "openstack_key"
}

locals {
  os_creds = ephemeral.vault_kv_secret_v2.os.data
}

provider "openstack" {
  auth_url                      = local.os_creds["OS_AUTH_URL"]
  application_credential_id     = local.os_creds["OS_APPLICATION_CREDENTIAL_ID"]
  application_credential_secret = local.os_creds["OS_APPLICATION_CREDENTIAL_SECRET"]
  region                        = var.region
}

module "instances" {
  source         = "./modules/compute"
  vms            = var.vms
  region         = var.region
  ovh_project_id = var.ovh_project_id
}

output "private_keys" {
  value     = module.instances.private_keys
  sensitive = true
}
