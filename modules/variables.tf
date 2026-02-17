variable "region" {
  type        = string
  default     = "SBG5"
  description = "Région OpenStack"
}

# OVH project et clés
variable "ovh_project_id" {
  type        = string
  description = "ID du projet OVHcloud (service_name)"
}

variable "ovh_endpoint" {
  type        = string
  default     = "ovh-eu"
  description = "OVH API endpoint (ovh-eu, ovh-us, etc.)"
}

variable "ovh_application_key" {
  type        = string
  description = "OVH Application Key (ou via env OVH_APPLICATION_KEY)"
  default     = ""
}

variable "ovh_application_secret" {
  type        = string
  description = "OVH Application Secret (ou via env OVH_APPLICATION_SECRET)"
  default     = ""
}

variable "ovh_consumer_key" {
  type        = string
  description = "OVH Consumer Key (ou via env OVH_CONSUMER_KEY)"
  default     = ""
}

# OpenStack
variable "os_auth_url" {
  type        = string
  description = "URL d'authentification OpenStack"
}

variable "os_user" {
  type        = string
  description = "ID des identifiants d'application OpenStack"
}

variable "os_password" {
  type        = string
  description = "Secret des identifiants d'application OpenStack"
}

variable "os_project_name" {
  type        = string
  description = "Nom du projet OpenStack"
}

variable "user_name" {
  type        = string
  description = "Nom d'utilisateur OpenStack"
}

variable "os_domain" {
  type        = string
  description = "Domaine OpenStack"
  default     = "Default"
}

# --- Structure des VMs ---
# ... (variables de connexion inchangées)

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
