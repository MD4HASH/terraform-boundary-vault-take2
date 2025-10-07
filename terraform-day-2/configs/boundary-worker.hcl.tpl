
worker {
  name        = "boundary-worker"
  description = "Single-node worker"
  initial_upstreams = ["127.0.0.1:9201"]
  public_addr = "${worker_public_ip}:9202"
}

listener "tcp" {
  address     = "0.0.0.0:9202"
  purpose     = "proxy"
  tls_disable = true
}


kms "transit" {
  purpose    = "worker-auth"
  address    = "http://127.0.0.1:8200"
  token      = "${vault_token}"
  key_name   = "${transit_key_name}"
  mount_path = "${vault_mount}"
}