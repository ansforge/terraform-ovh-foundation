variable "region" {
  type        = string
  description = "Région OVH Public Cloud (ex: EU-WEST-PAR)"
}

variable "ovh_project_id" {
  type        = string
  description = "ID du projet Public Cloud (service_name)"
}

variable "vms" {
  description = "Map des configurations des machines virtuelles de la Landing Zone"
  type = map(object({
    name          = string
    flavor_id     = string
    image_id      = string
    key_name      = string
    extra_disk_gb = optional(number, 0)
    networks      = list(object({
      name    = string
      ip      = string
      enabled = bool
    }))
    tags = map(string)
  }))
}
