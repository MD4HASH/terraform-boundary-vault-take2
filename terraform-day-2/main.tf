terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
    }
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


# the vault init can be exported in JSON and easily referenced throughout.   
locals {
  vault_init = jsondecode(file("${path.module}/../secrets/vault_init.json"))
}


# Vault Provider
provider "vault" {
  address = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:8200"
  token   = local.vault_init.root_token
}

# Unseal vault
resource "null_resource" "unseal_vault" {
  provisioner "local-exec" {
    environment = {
      VAULT_ADDR = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:8200"
    }
    command = <<EOT
vault operator unseal ${local.vault_init.unseal_keys_b64[0]}
vault operator unseal ${local.vault_init.unseal_keys_b64[1]}
vault operator unseal ${local.vault_init.unseal_keys_b64[2]}
EOT
  }
}


#Create static KV mount

resource "vault_mount" "boundary" {
  path = "secrets"
  type = "kv"
  options = {
    version = "2" # KV v2
  }
  depends_on = [null_resource.unseal_vault]
}

# Create transit mount to be used for boundary kms
resource "vault_mount" "transit" {
  path = "boundary_kms"
  type = "transit"
}

# Create single transit key to be used for root, worker auth, and 
resource "vault_transit_secret_backend_key" "boundary" {
  backend          = vault_mount.transit.path
  name             = "boundary"
  type             = "aes256-gcm96"
  deletion_allowed = true
}

# Don't do this in production
resource "vault_policy" "boundary" {
  name   = "boundary-all"
  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# create a renewable orphaned key for boundary to authenticate to vault
resource "vault_token" "boundary_vault_token" {
  display_name      = "boundary-vault-token"
  policies          = [vault_policy.boundary.name]
  renewable         = true
  period            = "24h"
  no_parent         = true
  no_default_policy = true
  depends_on        = [vault_policy.boundary, null_resource.unseal_vault]
}

# Save private file in secrets directory (ensure "secrets/*" is included in .gitignore)
resource "local_file" "boundary_vault_token" {
  content  = vault_token.boundary_vault_token.client_token
  filename = "../secrets/boundary_vault_token"
}

# upload targer servers ssh key to vault

resource "vault_kv_secret_v2" "target_key" {
  mount = vault_mount.boundary.path
  name  = "target_key"

  data_json = jsonencode({
    private_key = file("../secrets/target_key.pem")
    user        = "ubuntu"
  })
}


# render boundary configs
resource "null_resource" "copy_boundary_configs" {
  triggers = {
    kms_token_id = vault_token.boundary_vault_token.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("../secrets/operator_key.pem")
    host        = data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/boundary.d",
      "sudo chown -R ubuntu:ubuntu /etc/boundary.d",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/configs/boundary-controller.hcl.tpl", {
      vault_token      = vault_token.boundary_vault_token.client_token
      vault_mount      = vault_mount.transit.path
      transit_key_name = vault_transit_secret_backend_key.boundary.name
    })
    destination = "/etc/boundary.d/boundary-controller.hcl"
  }

  provisioner "file" {
    content = templatefile("${path.module}/configs/boundary-worker.hcl.tpl", {
      vault_token      = vault_token.boundary_vault_token.client_token
      vault_mount      = vault_mount.transit.path
      worker_public_ip = data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip
      transit_key_name = vault_transit_secret_backend_key.boundary.name
    })
    destination = "/etc/boundary.d/boundary-worker.hcl"
  }
  # initialize boundary
  provisioner "remote-exec" {
    script = "./init.sh"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ../secrets/operator_key.pem ubuntu@${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:~/boundary_init ../secrets/boundary_init"
  }

  depends_on = [vault_token.boundary_vault_token, vault_mount.transit]
}
