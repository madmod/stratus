
// Configure the matchbox provider.
provider "matchbox" {
  endpoint    = "${local.matchbox_grpc_endpoint}"
  client_cert = "${file("../tls/client.crt")}"
  client_key  = "${file("../tls/client.key")}"
  ca          = "${file("../tls/ca.crt")}"
}

provider "local" {
  version = "~> 1.0"
  alias = "default"
}

provider "null" {
  version = "~> 1.0"
  alias = "default"
}

provider "template" {
  version = "~> 1.0"
  alias = "default"
}

provider "tls" {
  version = "~> 1.0"
  alias = "default"
}
