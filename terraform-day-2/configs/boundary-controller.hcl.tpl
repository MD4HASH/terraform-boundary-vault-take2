
disable_mlock = true

listener "tcp" {
  address     = "0.0.0.0:9200"
  purpose     = "api"
  tls_disable = true
}

listener "tcp" {
  address     = "0.0.0.0:9201"
  purpose     = "cluster"
  
}

controller {
  name        = "boundary-controller"
  description = "Single-node controller"
  database {
    url = "postgresql://boundary:derp@localhost:5432/boundary?sslmode=disable"
  }
}


kms "transit" {
  purpose    = "root"
  address    = "http://127.0.0.1:8200"
  token      = "${vault_token}"
  key_name   = "${transit_key_name}"
  mount_path = "${vault_mount}"
}

kms "transit" {
  purpose    = "worker-auth"
  address    = "http://127.0.0.1:8200"
  token      = "${vault_token}"
  key_name   = "${transit_key_name}"
  mount_path = "${vault_mount}"
}



