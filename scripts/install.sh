#!/bin/bash
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

peers=""
declare -A peers_addrs

if [ "$os_name" != "darwin" ] && [ "$os_name" != "linux" ]; then
  >&2 echo "Sorry, this script supports only Linux or macOS operating systems."
  exit 1
fi

function usage {
	# Display Help
	echo "Install script for Vault Cluster"
	echo
	echo "Syntax: $script_name create|unseal|dev|destroy [-n|p|c|u]"
	echo "Create options:"
	echo "  -n     Node name."
    echo "  -p     Peer URLs."
    echo "  -c     Cluster Name."
	echo "Unseal options: "
	echo "  -n     Node name."
    echo "  -p     Peer URLs."
    echo "  -c     Cluster Name."
    echo "  -u     Unseal Key."
	echo "Dev options: none"
	echo "Destroy options: none"
	echo "ENV vars: "
	echo "  VAULT_VERSION           Vault version to be installed."
    echo "  TERRAFORM_VERSION       Terraform version to be installed."
	echo
}

install_deps() {
    local _product=$1
    local _version=$2

    printf "\n%s" \
        "Installing product: $product, version: $version" \
        ""
    apk add --update --virtual .deps --no-cache gnupg libcap-setcap openssl && \
        wget https://releases.hashicorp.com/${_product}/${_version}/${_product}_${_version}_linux_amd64.zip && \
        wget https://releases.hashicorp.com/${_product}/${_version}/${_product}_${_version}_SHA256SUMS && \
        wget https://releases.hashicorp.com/${_product}/${_version}/${_product}_${_version}_SHA256SUMS.sig && \
        wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
        gpg --verify ${_product}_${_version}_SHA256SUMS.sig ${_product}_${_version}_SHA256SUMS && \
        grep ${_product}_${_version}_linux_amd64.zip ${_product}_${_version}_SHA256SUMS | sha256sum -c && \
        unzip ${_product}_${_version}_linux_amd64.zip -d /tmp && \
        mv /tmp/${_product} /usr/local/bin/${_product} && \
        rm -f ${_product}_${_version}_linux_amd64.zip ${_product}_${_version}_SHA256SUMS ${_product}_${_version}_SHA256SUMS.sig && \
        rm -f /tmp/LICENSE.txt && \
        apk del .deps
}

function regenerate_sshd_keys {
	if [ -f /etc/ssh/ssh_host_rsa_key ]; then
    	rm -f /etc/ssh/ssh_host_*
	fi   

    ssh-keygen -q -N "" -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key
    ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
    ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
}

function create_tls_peers {
	for peer in ${peer_addrs[@]};
	do
		peers+=$(cat <<EOF
    retry_join {
        leader_api_addr             = "https://$peer:$port"
        leader_ca_cert_file         = "$vault_config/certs/vault.cert.pem"
        leader_client_cert_file     = "$vault_config/certs/vault-node.crt"
        leader_client_key_file      = "$vault_config/certs/vault-node.key"
    }
EOF
		)

		peers+=$'\n'
	done
}

function create_non_tls_peers {
	for peer in ${peer_addrs[@]};
	do
		peers+=$(cat <<EOF
    retry_join {
        leader_api_addr             = "http://$peer:$port"
    }
EOF
		)

		peers+=$'\n'
	done
}

function create_tls_config {
    printf "\n%s" \
        "Creating main config ($vault_config_file)" \
        ""
    sleep 2 # Added for human readability

    create_tls_peers "$@"

    tee $vault_config_file  <<EOF
ui                      = true
log_level               = "trace"
api_addr                = "https://$ip:$port"
cluster_addr  			= "https://$ip:$cport"
disable_mlock           = true
disable_cache           = true
cluster_name            = "$cluster_name"

listener "tcp" {
   address              = "0.0.0.0:$port"
   tls_disable          = false
   tls_cert_file        = "$vault_config/certs/vault-node.crt"
   tls_key_file         = "$vault_config/certs/vault-node.key"
   tls_client_ca_file   = "$vault_config/certs/vault.cert.pem"
#   tls_cipher_suites    = "TLS_TEST_128_GCM_SHA256,TLS_TEST_128_GCM_SHA256,TLS_TEST20_POLY1305,TLS_TEST_256_GCM_SHA384,TLS_TEST20_POLY1305,TLS_TEST_256_GCM_SHA384"
}

storage "raft" {
    path        = "$data_folder"
    node_id     = "$node_id"

$peers
}
EOF
}

function create_non_tls_config {
    printf "\n%s" \
        "Creating main config ($vault_config_file)" \
        ""
    sleep 2 # Added for human readability

    create_non_tls_peers "$@"

    tee $vault_config_file  <<EOF
ui                      = true
log_level               = "info"
api_addr                = "http://$ip:$port"
cluster_addr  			= "http://$ip:$cport"
disable_mlock           = true
disable_cache           = true
cluster_name            = "$cluster_name"

listener "tcp" {
   address              = "0.0.0.0:8200"
   tls_disable          = true
}

storage "raft" {
    path        = "$data_folder"
    node_id     = "$node_id"

$peers
}
EOF
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
    ( export VAULT_ADDR="https://$ip:$port" && export VAULT_CACERT="$vault_config/certs/vault-node.crt" && vault "$@" )
}

function unseal_server {
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

    if [ -z ${unseal_key:+x} ]; then
        INIT_RESPONSE=$(vault_srv operator init -format=json  -key-shares=1 -key-threshold=1)

        UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
        VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

        vault_srv operator unseal "$UNSEAL_KEY"

        echo "$UNSEAL_KEY" > unseal_key-vault
        echo "$VAULT_TOKEN" > root_token-vault

        printf "\n%s" \
            "Unseal key: $UNSEAL_KEY" \
            "Root token: $VAULT_TOKEN" \
            ""
    else
        UNSEAL_KEY=$unseal_key
        vault_srv operator unseal "$UNSEAL_KEY"
    fi
}

# function setup_admin {
#     vault_srv login "$VAULT_TOKEN"

#     printf "\n%s" \
#         "creating admins policy, enabling userpass authentication and revoking root token" \
#         ""
#     sleep 2 # Added for human readability

#     while true;
#     do
#         read -p "New Admin Password: " admin_password
#         read -p "Confirm Admin Password: " confirm_admin_password

#         if [[ $admin_password == $confirm_admin_password ]]; then
#             break
#         else
#             echo "Passwords do not match ! Try again ..."
#         fi
#     done

#     vault_srv policy write admins <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/policies/admin.hcl)
#     vault_srv auth enable userpass
#     vault_srv write auth/userpass/users/admin password=$admin_password policies=admins
#     vault_srv token revoke "$VAULT_TOKEN"    
# }

if [ -z "$1" ]; then usage; fi

command=$1

shift 1

while getopts ":n:p:c:u" o; do
    case "${o}" in
        n)
            echo "Node ID: ${OPTARG}"
            node_id=${OPTARG}
            ;;
        p)
            echo "Peer URLs: ${OPTARG}"
	        peer_addrs+=(${OPTARG})
            ;;
        c)
            echo "Cluster Name: ${OPTARG}"
	        cluster_name=(${OPTARG})
            ;;
        u)
            echo "Unseal Key: ${OPTARG}"
            unseal_key=${OPTARG}
            ;;
        *)
            usage

            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

vault_version=${VAULT_VERSION:-"1.19.2"}
terraform_version=${TERRAFORM_VERSION:-"1.11.3"}

echo "Vault version: $vault_version"
echo "Terraform version: $terraform_version"
sleep 2 # Added for human readability

if [ $command == "create" ]; then
	install_deps "vault" $vault_version
    install_deps "terraform" $terraform_version

	if [ -z "$node_id" ] || [ -z "$cluster_name" ] || [ -z "$peer_addrs" ]; then
		usage

		exit 1
	fi

	mkdir -p $vault_config

	mkdir -p $data_folder
	chown $user:$group $data_folder

	rm -f $vault_config_file

    create_non_tls_config "$@"

	chown $user:$group $vault_config_file

    regenerate_sshd_keys
	
    rm -f $service_file

	create_service "$@"

	chmod 755 $service_file

	start_service "$@"

	sleep 5 # Waiting for Vault server to start
elif [ $command == "dev" ]; then
	install_deps "vault" $vault_version
    install_deps "terraform" $terraform_version

    echo " "
    echo " "
    echo "Vault installed. Run server: "
    echo " "
    echo "$ vault server -dev -dev-root-token-id root &"
    echo "$ export VAULT_ADDR=http://127.0.0.1:8200"
    echo "$ export VAULT_TOKEN=root"

    exit 1
elif [ $command == "unseal" ]; then
	if [ -z "$node_id" ] || [ -z "$cluster_name" ] || [ -z "$peer_addrs" ]; then
		usage

		exit 1
	fi

    #read PKI certificates from Vault

	stop_service "$@"

	rm -f $vault_config_file

    create_tls_config "$@"

	chown $user:$group $vault_config_file

    unseal_server "$@"
elif [ $command == "destroy" ]; then
	rm -f $vault_config_file
	rm -f $service_file
	rm -f $pidfile

	stop_service "$@"
else
    usage
fi
