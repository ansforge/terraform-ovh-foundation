variable "region" {                
  type        = string                
  description = "Région OpenStack"                
}                
                
variable "ovh_project_id" {                
  type        = string                
  description = "ID du projet OVHcloud (service_name)"                
}                
                
variable "vms" {                
  description = "Map des configurations des VMs"                
  type = map(object({                
    name          = string                
    flavor_id     = string                
    image_id      = string                 
    key_name      = string                
    extra_disk_gb = optional(number, 0)                
    networks      = list(object({                
      name    = string                
      ip      = optional(string)                
      enabled = bool
    }))                
    tags = map(string)                
  }))                
}
