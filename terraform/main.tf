
locals {
  matchbox_http_endpoint = "http://${var.matchbox_host_public}:8080"
  matchbox_grpc_endpoint = "${var.matchbox_host}:8081"
}


// Create a TLS private key for SSH.
resource "tls_private_key" "admin-ssh" {
  algorithm   = "ECDSA"
  # Use a curve compatible with OpenSSH. See: https://www.terraform.io/docs/providers/tls/r/private_key.html
  ecdsa_curve = "P256"
}


// Create a CoreOS-install profile
#resource "matchbox_profile" "coreos-install" {
#  name   = "coreos-install"
#  kernel = "http://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz"
#
#  initrd = [
#    "http://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz",
#  ]
#
#  args = [
#    "initrd=coreos_production_pxe_image.cpio.gz",
#    "coreos.config.url=${local.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
#    "coreos.first_boot=yes",
#    "console=tty0",
#    "console=ttyS0",
#  ]
#
#  container_linux_config = "${file("./templates/coreos-install.yaml.tmpl")}"
#}
#
#
#// Create a simple profile which just sets a SSH authorized_key
#resource "matchbox_profile" "simple" {
#  name                   = "simple"
#  container_linux_config = "${file("./templates/simple.yaml.tmpl")}"
#}
#
#
#// Default matcher group for machines
#resource "matchbox_group" "default" {
#  name    = "default"
#  profile = "${matchbox_profile.coreos-install.name}"
#
#  # no selector means all machines can be matched
#  metadata {
#    ignition_endpoint  = "${local.matchbox_http_endpoint}/ignition"
#    ssh_authorized_key = "${tls_private_key.admin-ssh.public_key_openssh}"
#  }
#}
#
#
#// Match machines which have CoreOS Container Linux installed
#resource "matchbox_group" "node1" {
#  name    = "node1"
#  profile = "${matchbox_profile.simple.name}"
#
#  selector {
#    os = "installed"
#  }
#
#  metadata {
#    ssh_authorized_key = "${tls_private_key.admin-ssh.public_key_openssh}"
#  }
#}


# Get the absolute version of CoreOS and support "latest".
module "container-linux" {
  source = "git::https://github.com/coreos/tectonic-installer//modules/container_linux?ref=master"

  release_channel = "${var.container_linux_channel}"
  release_version = "${var.container_linux_version}"
}


module "bare-metal" {
  source = "git::https://github.com/poseidon/typhoon//bare-metal/container-linux/kubernetes?ref=v1.10.2"

  #providers = {
  #  local = "local.default"
  #  null = "null.default"
  #  template = "template.default"
  #  tls = "tls.default"
  #}

  # bare-metal
  cluster_name            = "${var.cluster_name}"
  matchbox_http_endpoint  = "${local.matchbox_http_endpoint}"
  container_linux_channel = "${var.container_linux_channel}"
  container_linux_version = "${module.container-linux.version}"

  # configuration
  k8s_domain_name    = "k8s.${var.cluster_domain}"
  ssh_authorized_key = "${tls_private_key.admin-ssh.public_key_openssh}"
  asset_dir          = "${path.root}/secrets/clusters/${var.cluster_name}"

  # machines
  controller_names   = ["${var.controller_names}"]
  controller_macs    = ["${var.controller_mac_addresses}"]
  controller_domains = ["${formatlist("%s.%s", var.controller_names, var.cluster_domain)}"]

  worker_names   = ["${var.worker_names}"]
  worker_macs    = ["${var.worker_mac_addresses}"]
  worker_domains = ["${formatlist("%s.%s", var.worker_names, var.cluster_domain)}"]
}
