# vault-boundary-poc

This repository deploys and automates the configuration of Hashicorp Boundary and vault with Terraform.  This repository contains a PoC web server environment that is fully deployable to AWS by terraform.

First of all, - **Remember to ensure that the /secrets directory is indcluded in your gitignore and that you run terraform destroy after use**.  This is an ephemeral PoC and should not be left online or used to host sensitive information.

The environment is configured such that:

- There is a VPC, two EC2 instances, and related security groupss/network configuration
- `vault-boundary-vsi` is configured with three services:
  - vault for secrets management
    - vault is also configured with the transit plugin for KMS management
  - `boundary-controller` - the control plane service or boundary
  - `boundary-worker` - the dataplane/proxy component of boundary
- `vault-boundary-vsi` is configured such that:
  - a boundary client can authenticate, request access to a credential, and that credential will be retrieved from vault and used to proxy a connection to the `target-vsi`
  - the boundary-controller/boundary-worker services communicate securely wiht a self-signed cert and the vault transit kms plugin.

- The initialization and configuration of these services involve several sequencing challenges that require the terraform to be applied in three stages

## terraform-day-1

- Deploys a VPC, two EC2 instances, and security groups
- Creates ssh keys for the VSIs and stores them in AWS, such that the servers can be accessed at
  - `ssh ../secrets/operator_key.pem ubuntu@<public ip>`
- Renders service files for Vault, Boundary-controller, and Boundary-worker
- Renders config files for vault
- Initializes vault and exports information required for service configuration to the /secrets directory (which is excluded from the git repository)

## terraform-day-2

- Ingests information from the state of `terraform-day-1` in order to continue deploying Boundary and vault.
- Creates a static key store to store the targets ssh key
- Creates a transit store to facilitate boundary controller/worker kms communication
- Creates a target in boundary and associates it to the ssh key configured in vault
- Renders boundary configuration and runs boundary-init
- Exports information from boundary init to the /secrets directory, to be used in the next stage

## terraform-day-3

- Ingests information from the state of `terraform-day-1` in order to continue deploying Boundary and vault.
- Uses the information gathered in stage one and two to authenticate and configure boundary
- Creates a renewable/orphaned token for use wiht the boundary model
- Configures boundary scopes, groups, a target, and necessary associations

# Deployment Instructions

1. Clone this repository
    - `git clone git@github.com:MD4HASH/poc-coalfire.git`
2. Install [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. Authenticate to AWS by defining the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
    - `export AWS_ACCESS_KEY_ID=`
    - `export AWS_SECRET_ACCESS_KEY=`
4. Initialize terraform
    - `terraform init`
5. Run the following commands in order from the `terraform-day-1`, `terraform-day-2`, `terraform-day-3` directories
    - `terraform plan`, `terraform apply`
6. Each step will output rendered instructions for proceeding that you can view with
    - `terraform output boundary_ssh_instructions`
    - between day 1 and day 2, you will need to manually enter two variables.   Instructions from this are provided  in `boundary_ssh_instructions`

# Operational Instructions

### Set Boundary address and auth method

```
export BOUNDARY_ADDR="http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200"
export BOUNDARY_AUTH_METHOD_ID="${var.auth_method_id}"
export BOUNDARY_PASSWORD='${data.terraform_remote_state.day1.outputs.boundary_password}'
```

### Authenticate to Boundary as admin

```
boundary authenticate password \
  -login-name ${var.auth_method_login_name} \
  -password env://BOUNDARY_PASSWORD \
  -auth-method-id $BOUNDARY_AUTH_METHOD_ID
```

### Explore boundary

```
boundary scopes list -recursive
boundary targets list --scope-id <project-scope-id>
boundary connect ssh -target-id <ssh-target-id>
```

# Recommended Improvements

The following reccomendations are given in order of priority:

- Front boundary with an lb.  Obtain a signed certificate for the load balancer, redirect all incoming web connections to HTTPS (443)
- Add logging throughout.  Cloudwatch agents on the EC2 instances, ALB Access logs, Cloud Trail logs for user API calls
- Front the ALB with AWS WAF
- Implement AWS Systems Manager on the EC2 instances, and scan for vulnerabilities and benchmark compliance with AWS Inspector
- Use a CIS-hardened AMI for the EC2 instances
- Replace the management server with a Bastion product like Teleport or Hashicorp boundary.  Configure HA.
- Define the ALB with a module instead of raw resources
- The management ssh key, used by the management server to access the application servers, should be stored in and retrieved from AWS Secrets Manager or the System Parameter Store
- refactor to use less provisioners.   They are non-stateful and an anti-pattern.
- The egress policies for all SGs are wide open.  They should filter at least by port.
- Improve tagging
- The "backend subnet" is empty, and should be removed
