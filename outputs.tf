###############
# Bitwarden
###############

output "bitwarden_admin_token" {
  value = data.external.bitwarden_admin_token.result.token
}