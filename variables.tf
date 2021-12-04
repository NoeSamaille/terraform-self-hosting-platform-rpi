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

variable "bitwarden_server_admin_email" {
    type        = string
    description = "Bitwarden admin email."
}

variable "bitwarden_host" {
    type        = string
    description = "Bitwarden host name."
}

variable "bitwarden_smtp_host" {
    type        = string
    description = "SMTP server."
    default =   "smtp.gmail.com"
}

variable "bitwarden_smtp_from" {
    type        = string
    description = "Email to use for sending emails (invitations, etc)."
}

variable "bitwarden_smtp_port" {
    type        = number
    description = "SMTP port."
    default     = 587
}

variable "bitwarden_smtp_ssl" {
    type        = bool
    description = "Flag indicating SSL should be enabled for SMTP."
    default     = true
}

variable "bitwarden_smtp_username" {
    type        = string
    description = "SMTP username."
}

variable "bitwarden_smtp_password" {
    type        = string
    description = "SMTP password."
}