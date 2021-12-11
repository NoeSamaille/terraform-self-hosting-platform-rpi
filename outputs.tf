###############
# Dashboard
###############

output "dashboard_admin_token" {
  value = data.external.dashboard_admin_token.result.token
}

###############
# Bitwarden
###############

output "bitwarden_admin_token" {
  value = var.bitwarden_admin_token
}

###############
# Nextcloud
###############

output "nextcloud_admin_password" {
  value = var.nextcloud_admin_password
}

###############
# Media
###############

output "transmission_username" {
  value = var.transmission_username
}
output "transmission_password" {
  value = var.transmission_password
}