#!/bin/sh
# Copyright (c) luminosita

set -e

script_name="$(basename "$0")"
os_name="$(uname -s | awk '{print tolower($0)}')"

ip=`ip a show dev eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'`

port=8200
cport=8201

user=vault
group=vault

product=vault

vault_config=/etc/vault.d
vault_config_file="$vault_config/vault.hcl"
data_folder="/var/lib/vault"
service_file="/etc/init.d/vault"
pidfile="/run/vault/vault.pid"

if [ "$os_name" != "darwin" ] && [ "$os_name" != "linux" ]; then
  >&2 echo "Sorry, this script supports only Linux or macOS operating systems."
  exit 1
fi

function usage {
	# Display Help
	echo "Add description of the script functions here."
	echo
	echo "Syntax: $script_name create|destroy [-v|n|a|t]"
	echo "Create options:"
	echo "  -v     Vault version."
	echo "  -n     Node name."
	echo "  -a     Transit server url."
	echo "  -t     Transit server token."
	echo "Destroy options: none"
	echo
}

function install_deps {
    printf "\n%s" \
        "Installing dependencies packages" \
        ""
    sleep 2 # Added for human readability

    apk add --update libcap-setcap openssl curl jq

    printf "\n%s" \
        "Installing product: $product, version: $version" \
        ""
    apk add --update --virtual .deps --no-cache gnupg libcap-setcap openssl && \
        cd /tmp && \
        wget https://releases.hashicorp.com/${product}/${version}/${product}_${version}_linux_amd64.zip && \
        wget https://releases.hashicorp.com/${product}/${version}/${product}_${version}_SHA256SUMS && \
        wget https://releases.hashicorp.com/${product}/${version}/${product}_${version}_SHA256SUMS.sig && \
        wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
        gpg --verify ${product}_${version}_SHA256SUMS.sig ${product}_${version}_SHA256SUMS && \
        grep ${product}_${version}_linux_amd64.zip ${product}_${version}_SHA256SUMS | sha256sum -c && \
        unzip /tmp/${product}_${version}_linux_amd64.zip -d /tmp && \
        mv /tmp/${product} /usr/local/bin/${product} && \
        rm -f /tmp/${product}_${version}_linux_amd64.zip ${product}_${version}_SHA256SUMS ${version}/${product}_${version}_SHA256SUMS.sig && \
        apk del .deps
}

function create_user {
    printf "\n%s" \
        "Creating user ($user:$group)" \
        ""
    sleep 2 # Added for human readability

    addgroup -S $group
    adduser -G $group -S -s /bin/sh $user
}

function delete_user {
    printf "\n%s" \
        "Deleting user ($user:$group)" \
        ""
    sleep 2 # Added for human readability

    deluser $user
}

function create_transit_config {
    printf "\n%s" \
        "Creating transit config ($vault_config_file)" \
        ""
    sleep 2 # Added for human readability

    tee $vault_config_file 1> /dev/null <<EOF
disable_mlock           = true
ui                      = true

listener "tcp" {
    address             = "$ip:$port"
    tls_disable = true
}

storage "inmem" {}
EOF
}

function create_cluster_bootstrap_config {
    printf "\n%s" \
        "Creating main config ($vault_config_file)" \
        ""
    sleep 2 # Added for human readability

    tee $vault_config_file 1> /dev/null <<EOF
api_addr                = "https://$ip:$port"
cluster_addr  		    = "https://$ip:$cport"
disable_mlock           = true
ui                      = true

listener "tcp" {
    address             = "$ip:$port"
    cluster_address     = "$ip:$cport"
    tls_cert_file       = "$vault_config/vault-cert.pem"
    tls_key_file        = "$vault_config/vault-key.pem"
}

storage "raft" {
    path        = "$data_folder"
    node_id     = "$node_id"
}

seal "transit" {
   address            = "$transit_addr"
   # token is read from VAULT_TOKEN env
   token              = "$transit_token"
   disable_renewal    = "false"

   // Key configuration
   key_name           = "unseal_key"
   mount_path         = "transit/"
}
EOF

}

function create_config {
    printf "\n%s" \
        "Creating main config ($vault_config_file)" \
        ""
    sleep 2 # Added for human readability

    tee $vault_config_file 1> /dev/null <<EOF
api_addr                = "https://$ip:$port"
cluster_addr  		    = "https://$ip:$cport"
disable_mlock           = true
ui                      = true

listener "tcp" {
    address             = "$ip:$port"
    cluster_address     = "$ip:$cport"
    tls_cert_file       = "$vault_config/vault-cert.pem"
    tls_key_file        = "$vault_config/vault-key.pem"
}

storage "raft" {
    path        = "$data_folder"
    node_id     = "$node_id"
}
EOF

}

function create_certs {
    printf "\n%s" \
        "Creating certificates" \
        ""
    sleep 2 # Added for human readability

    openssl req -x509 -newkey rsa:4096 -sha256 -days 365 \
        -nodes -keyout $vault_config/vault-key.pem -out $vault_config/vault-cert.pem \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:$ip"

    chown $user:$group $vault_config/vault-key.pem
    chown $user:$group $vault_config/vault-cert.pem
}

function create_service {
    printf "\n%s" \
        "Creating system service" \
        ""
    sleep 2 # Added for human readability

    vault_binary=$(which vault)

    tee $service_file 1> /dev/null <<EOF
#!/sbin/openrc-run

name=\$RC_SVCNAME
cfgfile="$vault_config_file"
command="$vault_binary"
command_args="server -config=$vault_config_file"
command_user="vault"
command_background=true
pidfile="$pidfile"

depend() {
  need net
}

start_pre() {
  checkpath --directory --owner \$command_user:\$command_user --mode 0775 /run/\$RC_SVCNAME
}
EOF
}

function start_service {
    printf "\n%s" \
        "Starting system service" \
        ""
    sleep 2 # Added for human readability

    #On Linux, to give the Vault executable the ability to use the mlock syscall without running the process as root
    setcap cap_ipc_lock=+ep $(readlink -f $(which vault))

    rc-update add vault
    rc-service vault start
}

function stop_service {
    printf "\n%s" \
        "Stoping system service" \
        ""
    sleep 2 # Added for human readability

	rc-service -s vault stop
	rc-update del vault
}

function vault_srv {
    (export VAULT_ADDR="http://$ip:$port" && vault "$@")
}

function setup_transit_server {
    printf "\n%s" \
    	"initializing transit server and capturing the unseal key and root token" \
    	""
    sleep 2 # Added for human readability

    if ! [ -f $pidfile ]; then
    	printf "\n%s" \
    		"Vault transit server is down, exiting " \
    		""
	    return
    fi

    INIT_RESPONSE=$(vault_srv operator init -format=json -key-shares 1 -key-threshold 1)

    UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
    VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

    echo "$UNSEAL_KEY" > unseal_key-vault
    echo "$VAULT_TOKEN" > root_token-vault

    printf "\n%s" \
        "Unseal key: $UNSEAL_KEY" \
        "Root token: $VAULT_TOKEN" \
        ""

    printf "\n%s" \
    	"unsealing and logging in" \
    	""
    sleep 2 # Added for human readability

    vault_srv operator unseal "$UNSEAL_KEY"
    vault_srv login "$VAULT_TOKEN"

    printf "\n%s" \
    	"enabling the transit secret engine and creating a key to auto-unseal vault cluster" \
    	""
    sleep 2 # Added for human readability

    vault_srv secrets enable transit
    vault_srv write -f transit/keys/unseal_key
}

function setup_server {
    printf "\n%s" \
        "initializing server and capturing the recovery key and root token" \
        ""
    sleep 2 # Added for human readability

    if ! [ -f $pidfile ]; then
    	printf "\n%s" \
    		"Vault server is down, exiting " \
    		""
	    return
    fi

    # Initialize the second node and capture its recovery keys and root token
    INIT_RESPONSE=$(vault_srv operator init -format=json -recovery-shares 1 -recovery-threshold 1)

    RECOVERY_KEY=$(echo "$INIT_RESPONSE" | jq -r .recovery_keys_b64[0])
    VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

    echo "$RECOVERY_KEY" > recovery_key-vault
    echo "$VAULT_TOKEN" > root_token-vault

    printf "\n%s" \
    	"Recovery key: $RECOVERY_KEY" \
    	"Root token: $VAULT_TOKEN" \
    	""

    printf "\n%s" \
    	"waiting to finish post-unseal setup (15 seconds)" \
    	""

    sleep 15

    printf "\n%s" \
    	"logging in and enabling the KV secrets engine" \
    	""
    sleep 2 # Added for human readability

    vault_srv login "$VAULT_TOKEN"

    printf "\n%s" \
    	"creating admins policy, enabling userpass authentication and revoking root token" \
    	""
    sleep 2 # Added for human readability

    while true;
    do
        read -p "New Admin Password: " admin_password
        read -p "Confirm Admin Password: " confirm_admin_password

        if [[ $admin_password == $confirm_admin_password ]]; then
            break
        else
            echo "Passwords do not match ! Try again ..."
        fi
    done

    vault_srv policy write admins <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/policies/admins.hcl)
    vault_srv auth enable userpass
    vault_srv write auth/userpass/users/admin password=$admin_password policies=admins
    vault_srv token revoke "$VAULT_TOKEN"
}

if [ -z "$1" ]; then usage; fi

case "$1" in
	create)
	    command="create"
	    ;;
	destroy)
	    command="destroy"
	    ;;
	/?)
	    # Invalid option
            echo "Error: Invalid option"
	    exit;;
esac

shift 1

while getopts ":n:v:a:t:" o; do
    case "${o}" in
        n)
            node_id=${OPTARG}
            ;;
        v)
            version=${OPTARG}
            ;;
        a)
            transit_addr=${OPTARG}
            ;;
        t)
            transit_token=${OPTARG}
            ;;
        *)
            usage

            return
            ;;
    esac
done

shift $((OPTIND-1))

if [ $command == "create" ]; then
	if [ -z "$version" ]; then
		usage

		return
	fi

	# install_deps "$@"
	# create_user "$@"

	# mkdir -p $vault_config

	# mkdir -p $data_folder
	# chown $user:$group $data_folder

	rm -f $vault_config_file

	if [ -z "${node_id}" ] || [ -z "${transit_addr}" ] || [ -z "${transit_token}" ]; then
		create_transit_config "$@"
	else
		create_cluster_bootstrap_config "$@"
		create_certs "$@"
	fi

	chown $user:$group $vault_config_file

	rm -f $service_file

	create_service "$@"

	chmod 755 $service_file

	start_service "$@"

	sleep 5 # Waiting for Vault server to start

	if [ -z "${node_id}" ] || [ -z "${transit_addr}" ] || [ -z "${transit_token}" ]; then
		setup_transit_server "$@"
	else
		setup_server "$@"
	fi
else
	rm -f $vault_config_file
	rm -f $service_file
	rm -f $pidfile

	delete_user "$@"
	stop_service "$@"
fi