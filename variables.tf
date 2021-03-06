#####################
# General
#####################

variable "domain" {
  type        = string
  description = "Base domain name of your self-hosted services."
}
variable "smtp_from" {
  type        = string
  description = "Email to use for sending emails (invitations, etc)."
}
variable "smtp_host" {
  type        = string
  description = "SMTP server."
  default     = "smtp.gmail.com"
}
variable "smtp_port" {
  type        = number
  description = "SMTP port."
  default     = 587
}
variable "smtp_ssl" {
  type        = bool
  description = "Flag indicating SSL should be enabled for SMTP."
  default     = true
}
variable "smtp_username" {
  type        = string
  description = "SMTP username."
}
variable "smtp_password" {
  type        = string
  description = "SMTP password."
}
variable "ovpn_username" {
  type        = string
  description = "OpenVPN username."
}
variable "ovpn_password" {
  type        = string
  description = "OpenVPN password."
}

#####################
# MetalLB
#####################

variable "metallb_addresses_first" {
  type        = string
  description = "First address of the address-pool from which MetalLB will dedicate a virtual IP to be used as load balancer for an application."
}

variable "metallb_addresses_last" {
  type        = string
  description = "Last address of the address-pool from which MetalLB will dedicate a virtual IP to be used as load balancer for an application."
}

#####################
# cert-manager
#####################

variable "cert_manager_issuer_email" {
  type        = string
  description = "Email to be registered to certificate issuer."
}

#####################
# Bitwarden
#####################

variable "deploy_bitwarden" {
  type        = bool
  description = "Flag indicating that Bitwarden should be deployed."
  default     = true
}
variable "bitwarden_host_path" {
  type        = string
  description = "Local host path in with to store bitwarden persistent data."
}
variable "bitwarden_signups_allowed" {
  type        = bool
  description = "Flag indicating that signups are to we allowed in bitwarden."
  default     = false
}
variable "bitwarden_invitations_allowed" {
  type        = bool
  description = "Flag indicating that invitations are to we allowed in bitwarden."
  default     = true
}
variable "bitwarden_admin_token" {
  type        = string
  description = "Bitwarden admin access token."
}
variable "bitwarden_server_admin_email" {
  type        = string
  description = "Bitwarden admin email."
}

#####################
# Node-RED
#####################

variable "deploy_node_red" {
  type        = bool
  description = "Flag indicating that Node-RED should be deployed."
  default     = true
}
variable "node_red_host_path" {
  type        = string
  description = "Local host path in with to store node-red persistent data."
}

#####################
# Nextcloud
#####################

variable "deploy_nextcloud" {
  type        = bool
  description = "Flag indicating that Nextcloud should be deployed."
  default     = true
}
variable "nextcloud_app_host_path" {
  type        = string
  description = "Local host path in with to store nextcloud app."
}
variable "nextcloud_data_host_path" {
  type        = string
  description = "Local host path in with to store nextcloud data."
}
variable "nextcloud_admin_password" {
  type        = string
  description = "Admin password to access Nextcloud."
}
variable "nextcloud_mail_enabled" {
  type        = bool
  description = "Flag indicating that emails are to we enabled Nextcloud."
  default   = true
}
variable "nextcloud_mail_domain" {
  type        = string
  description = "Email domain to use for Nextcloud."
  default     = "gmail.com"
}

#####################
# Media Center
#####################

variable "deploy_media_center" {
  type        = bool
  description = "Flag indicating that Media Center should be deployed."
  default     = true
}
variable "media_apps_host_path" {
  type        = string
  description = "Local host path in with to store media center app data."
}
variable "media_data_host_path" {
  type        = string
  description = "Local host path in with to store media center data."
}
variable "transmission_username" {
  type        = string
  description = "transmission username."
}
variable "transmission_password" {
  type        = string
  description = "transmission password."
}

