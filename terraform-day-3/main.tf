terraform {
  required_providers {
    boundary = {
      source = "hashicorp/boundary"
    }
  }
}

# Pull in state from day 1

data "terraform_remote_state" "day1" {
  backend = "local"
  config = {
    path = "../terraform-day-1/terraform.tfstate"
  }
}

# Boundary provider setup
provider "boundary" {
  addr                   = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200"
  auth_method_id         = var.boundary_auth_method_id
  auth_method_login_name = var.boundary_auth_method_login_name
  auth_method_password   = var.boundary_auth_method_password
}

# create org and project scopes
resource "boundary_scope" "dev-org" {
  name                     = "dev-scope"
  scope_id                 = "global"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "dev-project" {
  name                   = "dev-project"
  scope_id               = boundary_scope.dev-org.id
  auto_create_admin_role = true
}

# Create a vault crednetial store in boundary 

resource "boundary_credential_store_vault" "vault" {
  name     = "vault-store"
  scope_id = boundary_scope.dev-project.id
  address  = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:8200"
  token    = trimspace(file("../secrets/boundary_vault_token"))
}

resource "boundary_credential_library_vault" "ssh_key" {
  name                = "ssh-key-library"
  description         = "Library to fetch SSH key for target host"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "secrets/data/target_key"
}

# Create a target host
resource "boundary_target" "target_host" {
  name         = "target-host"
  scope_id     = boundary_scope.dev-project.id
  type         = "tcp"
  address      = data.terraform_remote_state.day1.outputs.target_ip
  default_port = 22

  brokered_credential_source_ids = [
    boundary_credential_library_vault.ssh_key.id
  ]
}
