### Install Vault in Alpine LXC

#### Prerequisite

Each cluster node needs to install the following packages:

- openssl
- jq
- bash

#### Vault Servers

For each cluster node

```bash
$ sudo su -c "VAULT_VERSION=1.19.2 bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) create -n <node name> -c <cluster name> -p <peerIP 1> -p <peerIP 2>" root
```

It will install Vault server and create `raft` data node

#### Unseal Servers

For the first cluster node ONLY !!!

```bash
$ export VAULT_ADDR=http://127.0.0.1:8200
$ vault operator init -key-shares=1 -key-threshold=1
Unseal Key 1: xxxxxxxx

Initial Root Token: xxxxxxxx

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.

$ export VAULT_TOKEN=<First Node Root Token>
$ vault operator unseal <First Node Unseal Key>
```

For all other cluster nodes

```bash
$ export VAULT_ADDR=http://127.0.0.1:8200
$ export VAULT_TOKEN=<First Node Root Token>
$ vault operator unseal <First Node Unseal Key>
```

#### Validate Cluster

List all Vault nodes

```bash
$ vault operator raft list-peers
```

### Terraform

Run on a separate machine. Create `vault.auto.tfvars` and set proper Vault endpoint

```bash
$ export TF_VAR_vault_token=<First Node Root Token>
$ terraform init
$ terraform plan
$ terraform apply
```

Copy vault-node.crt, vault-node.key and vault.cert.pem from output folder to each cluster node

```bash
$ scp vault-node.crt vault-node.key vault.cert.pem lxc@<node id>:./
```

On each cluster node move these three files into `/etc/vault.d/certs/` folder and change file ownership to `vault:vault`

#### Enable TLS 

Script will stop running Vault server, reconfigure with TLS supplied TLS certificate and restart Vault server

```bash
$ sudo su -c "TERRAFORM_VERSION=1.11.3 VAULT_VERSION=1.19.2 bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) tls -n <node name> -c <cluster name> -p <peerIP 1> -p <peerIP 2>" root
```

#### Unseal Servers - Part II

After each restart Vault servers need to be unsealed

For all other cluster nodes

```bash
$ export VAULT_ADDR=https://127.0.0.1:8200
$ export VAULT_CACERT=/etc/vault.d/certs/vault-node.crt
$ export VAULT_TOKEN=<First Node Root Token>
$ vault operator unseal <First Node Unseal Key>
```

>**NOTE:** Store securely `Unseal Key` since it is required for each server restart

#### Revoke Initial Root Token

Once cluster is fully deployed revoke `Initial Root Token`

```bash
$ vault write auth/userpass/users/<admin username> token_policies="admin_policy" password=<admin password>
$ vault token revoke <First Node Root Token>
```

#### Cleanup

We need to delete `Unseal Key` from the history

For all other cluster nodes

```bash
$ unset VAULT_TOKEN
$ rm .ash_history
```

### Recreate Root Token (requires `Unseal Key`)

```bash
$ vault operator generate-root -init
A One-Time-Password has been generated for you and is shown in the OTP field.
You will need this value to decode the resulting root token, so keep it safe.
Nonce         49d030ae-b910-545a-b25b-29a2c7241114
Started       true
Progress      0/1
Complete      false
OTP           FKOWLuLKGo2N5uaXUCEgjjtOb4
OTP Length    26

$ vault operator generate-root -otp="FKOWLuLKGo2N5uaXUCEgjjtOb4"
Operation nonce: 49d030ae-b910-545a-b25b-29a2c7241114
Unseal Key (will be hidden):
Nonce            49d030ae-b910-545a-b25b-29a2c7241114
Started          true
Progress         1/1
Complete         true
Encoded Token    NWUFbxkGFXwdNXY0dBxUb2YsKQoCGwYdMFE

$ vault operator generate-root -decode=NWUFbxkGFXwdNXY0dBxUb2YsKQoCGwYdMFE -otp FKOWLuLKGo2N5uaXUCEgjjtOb4
```

### Playground

#### Login with Admin User

```bash
$ vault login -method userpass username=admin
```

#### Secrets

```bash
$ vault secrets enable -path=secret kv-v2
$ vault kv put secret/laza pera=mika
$ vault kv get --format=json secret/laza | jq '.data.data'
$ vault kv list secret/
$ vault kv delete secret/laza
$ vault read -format=json sys/mounts    #read all mounts
```

### AppRole Authentication Method

>**NOTE:** Login as Admin user

```bash
$ vault auth enable approle
$ vault policy write jenkins -<<EOF
# Read-only permission on secrets stored at 'secret/data/mysql/webapp'
path "secret/data/mysql/webapp" {
  capabilities = [ "read" ]
}
EOF
$ vault write auth/approle/role/jenkins token_policies="jenkins" \
    token_ttl=1h token_max_ttl=4h
```

#### Create Test Data

```bash
$ vault kv put secret/mysql/webapp db_name="users" username="admin" password="passw0rd"
```
