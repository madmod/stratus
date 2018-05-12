#!/usr/bin/env bash

set -eo pipefail


: ${CLUSTER_NAME:="stratus"}
: ${CLUSTER_DOMAIN:="int.${CLUSTER_NAME}.inur.sh"}
: ${MATCHBOX_INTERNAL_DOMAIN:="host.docker.internal"}
: ${MATCHBOX_DOMAIN:="matchbox.svc.${CLUSTER_DOMAIN}"}

: ${CACHE_DIR:="$(pwd)/cache"}
: ${TLS_DIR:="$(pwd)/tls"}


mkdir -p ${CACHE_DIR}/matchbox{/var/lib/matchbox/assets,/etc/matchbox} ${CACHE_DIR}/terraform/root/.matchbox


(
  cd ${TLS_DIR}

  if [ ! -f ca.crt ]; then
    docker run --rm \
      -v ${TLS_DIR}:/tls \
      -e SAN="DNS.1:${MATCHBOX_INTERNAL_DOMAIN},DNS.2:${MATCHBOX_DOMAIN}" \
      --entrypoint sh \
      --workdir /tls \
      frapsoft/openssl \
      ./cert-gen
  fi

  cp -f ca.crt server.crt server.key ${CACHE_DIR}/matchbox/etc/matchbox
  cp -f ca.crt client.crt client.key ${CACHE_DIR}/terraform/root/.matchbox
)


# Don't block matchbox waiting for a password.
sudo true;


# Run matchbox in a Docker container.
(
  sudo docker run --rm --name matchbox \
    -v ${CACHE_DIR}/matchbox/var/lib/matchbox:/var/lib/matchbox:Z \
    -v ${CACHE_DIR}/matchbox/etc/matchbox:/etc/matchbox:Z,ro \
    -p 0.0.0.0:8080:8080 \
    -p 0.0.0.0:8081:8081 \
    quay.io/coreos/matchbox:latest -address=0.0.0.0:8080 -rpc-address=0.0.0.0:8081 -log-level=debug
) &


# Run dnsmasq in a Docker container.
#(
#  set -x
#  sudo docker run --rm --name dnsmasq \
#    --cap-add=NET_ADMIN \
#    --cap-add NET_BIND_SERVICE \
#    -p 5300:53/udp \
#    -p 6700:67/udp \
#    -p 6900:69/udp \
#    quay.io/coreos/dnsmasq \
#    -d -q \
#    --dhcp-range=10.1.1.1,proxy,255.255.0.0 \
#    --address=/${MATCHBOX_DOMAIN}/10.1.1.254 \
#    --enable-tftp --tftp-root=/var/lib/tftpboot \
#    --dhcp-userclass=set:ipxe,iPXE \
#    --pxe-service=tag:#ipxe,x86PC,"PXE chainload to iPXE",undionly.kpxe \
#    --pxe-service=tag:ipxe,x86PC,"iPXE",http://${MATCHBOX_DOMAIN}:8080/boot.ipxe \
#    --log-queries \
#    --log-dhcp
#) &


# Kill the containers when the script stops.
cleanup() {
  rv=$?
  docker kill matchbox >& /dev/null || true
  docker kill dnsmasq >& /dev/null || true
  exit $rv
}
trap "cleanup" INT TERM EXIT


# Run the Terraform in a Docker container.
sleep 2;
TERRAFORM="docker run --net=host --rm -v $(pwd)/terraform:/build -v ${CACHE_DIR}/terraform/root/.matchbox:/root/.matchbox:ro -e TF_VAR_matchbox_host=${MATCHBOX_INTERNAL_DOMAIN} -e TF_VAR_matchbox_host_public=${MATCHBOX_DOMAIN} -e TF_VAR_cluster_name=${CLUSTER_NAME} -e TF_VAR_cluster_domain=${CLUSTER_DOMAIN} kramergroup/terraform-matchbox"
$TERRAFORM init
$TERRAFORM apply --var-file="/build/envs/${CLUSTER_NAME}.tfvars"

# Keep running so we can watch the matchbox logs.
tail -f /dev/null
