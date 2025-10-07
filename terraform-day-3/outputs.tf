output "boundary_ssh_instructions" {
  value       = <<EOT
# ----------------------
# Boundary SSH Instructions
# ----------------------

# Set Boundary address
export BOUNDARY_ADDR=http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200

# Set your dev-admin password for authentication
export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=${var.boundary_auth_method_password}

# Authenticate with Boundary
AMPW_ID=${var.boundary_auth_method_id}
boundary authenticate password \
  -login-name admin \
  -auth-method-id "$AMPW_ID" \
  -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD

# Connect to target host via Boundary
boundary connect ssh --target-id x.x.x.x

EOT
  description = "Copy/paste these commands to authenticate and connect via Boundary SSH"
  sensitive   = true
}
