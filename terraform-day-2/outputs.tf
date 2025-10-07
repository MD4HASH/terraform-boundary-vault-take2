output "boundary_ssh_instructions" {
  value       = <<EOT
Run the following to view the boundary init output.   Copy and paste the auth method id and pw into the variables of day 3.

terraform output boundary_init_contents

EOT
  description = "Copy/paste these commands to authenticate and connect via Boundary SSH"
}

output "boundary_init_contents" {
  value     = file("../secrets/boundary_init")
  sensitive = true # optional, hides it in CLI output
}
