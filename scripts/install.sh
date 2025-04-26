#!/bin/bash
usage() { echo "Usage: $0 -n node_id -v version";  echo "Example: $0 -n Noa -v 1.19.2" 1>&2; return; }

while getopts ":n:v:" o; do
    case "${o}" in
        n)
            node_id=${OPTARG}
            ;;
        v)
            version=${OPTARG}
            ;;
        *)
            usage

            return
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${node_id}" ] || [ -z "${version}" ]; then
    usage

    return
fi

IP=`ip a show dev eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'`

PORT=8200
CPORT=8201

PRODUCT=vault
VERSION=$version

apk add --update libcap-setcap openssl curl
apk add --update --virtual .deps --no-cache gnupg libcap-setcap openssl && \
    cd /tmp && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    rm -f /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS ${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    apk del .deps

addgroup -S vault
adduser -G vault -S -s /bin/sh vault

vault_binary=$(which vault)
vault_config=/etc/vault.d
vault_config_file="$vault_config/vault.hcl"
data_folder="/var/lib/vault"

mkdir -p $vault_config

tee $vault_config_file <<EOF
api_addr                = "https://$IP:$PORT"
cluster_addr  		= "https://$IP:$CPORT"
disable_mlock           = true
ui                      = true

listener "tcp" {
    address       = "$IP:$PORT"
    tls_cert_file = "$vault_config/vault-cert.pem"
    tls_key_file  = "$vault_config/vault-key.pem"
}

backend "raft" {
    path    = "$data_folder"
    node_id = "$node_id"
}
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 365 \
      -nodes -keyout $vault_config/vault-key.pem -out $vault_config/vault-cert.pem \
      -subj "/CN=vault.lan" \
      -addext "subjectAltName=DNS:vault.lan,IP:$IP"

chown vault:vault $vault_config/vault-key.pem
chown vault:vault $vault_config/vault-cert.pem
chown vault:vault $vault_config_file

tee /etc/init.d/vault <<EOF
#!/sbin/openrc-run

name=\$RC_SVCNAME
cfgfile="$vault_config_file"
command="$vault_binary"
command_args="server -config=$vault_config_file"
command_user="vault"
command_background=true
pidfile="/run/\$RC_SVCNAME/\$RC_SVCNAME.pid"

depend() {
  need net
}

start_pre() {
  checkpath --directory --owner \$command_user:\$command_user --mode 0775 /run/\$RC_SVCNAME
}
EOF

chmod 755 /etc/init.d/vault

#On Linux, to give the Vault executable the ability to use the mlock syscall without running the process as root
setcap cap_ipc_lock=+ep $(readlink -f $(which vault))

mkdir -p $data_folder
chown vault:vault $data_folder

rc-update add vault
rc-service vault start