
variable "matchbox_host" {
  type        = "string"
  description = "Matchbox hostname for configuration (e.g. docker.host.internal)"
}

variable "matchbox_host_public" {
  type        = "string"
  description = "Matchbox hostname (e.g. matchbox.example.com)"
}

variable "cluster_name" {
  type        = "string"
  description = "Cluster name (e.g. my-cluster)"
}

variable "cluster_domain" {
  type        = "string"
  description = "Cluster domain suffix (e.g. my-cluster.example.com)"
}

variable "container_linux_channel" {
  type    = "string"
  default = "stable"

  description = <<EOF
(optional) The Container Linux update channel.
Examples: `stable`, `beta`, `alpha`
EOF
}

variable "container_linux_version" {
  type    = "string"
  default = "latest"

  description = <<EOF
The Container Linux version to use. Set to `latest` to select the latest available version for the selected update channel.
Examples: `latest`, `1465.6.0`
EOF
}

variable "controller_names" {
  type        = "list"
  description = "The names of k8s controller nodes."
}

variable "controller_mac_addresses" {
  type        = "list"
  description = "The MAC addresses of k8s controller nodes."
}

variable "worker_names" {
  type        = "list"
  description = "The names of k8s worker nodes."
}

variable "worker_mac_addresses" {
  type        = "list"
  description = "The MAC addresses of k8s worker nodes."
}
