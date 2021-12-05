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

#####################
# MetalLB
#####################

variable "metallb_addresses" {
  type        = string
  description = "Address-pool from which MetalLB will dedicate a virtual IP to be used as load balancer for an application."
  default     = "192.168.1.240-192.168.1.250"
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

variable "node_red_host_path" {
  type        = string
  description = "Local host path in with to store node-red persistent data."
}

#####################
# Nextcloud
#####################

variable "nextcloud_host_path" {
  type        = string
  description = "Local host path in with to store nextcloud persistent data."
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