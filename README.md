### Install Vault in Alpine LXC

#### Vault Server

```bash
$ sudo su -c "bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) create -n Noa -p https://172.16.20.12:8200 -p https://172.16.20.13:8200" root
```

sudo TERRAFORM_VERSION=1.9.5 bash install.sh dev

It will install clustered Vault server version 1.19.2 and create `raft` data node `Noa`

#### Initial Setup

```bash
$ export VAULT_ADDR="https://$(ip a show dev eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'):8200"
$ export VAULT_SKIP_VERIFY=true
$ vault operator init -key-shares=1 -key-threshold=1
Unseal Key 1: xxxxxxxxx

Initial Root Token: xxxxxxxxx

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

>**NOTE:** Store securely `Root Token` and `Unseal Key(s)`

#### Unseal Vault

```bash
$ vault operator unseal
Unseal Key (will be hidden): <Unseal Key 1>
```

#### Login

```bash
$ vault login
Token (will be hidden): <Root Token>
```

#### Add Admin User and Revoke Root Token

```bash
$ vault policy write admins <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/policies/admins.hcl)
$ vault auth enable userpass
$ vault write auth/userpass/users/admin password=<password> policies=admins
$ vault token revoke <Root Token>
$ vault login -method userpass username=admin
```

#### Add KV Admin User

```bash
$ vault policy write kv-admins <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/policies/kv-admins.hcl)
$ vault write auth/userpass/users/<username> password=<password> policies=kv-admins
$ vault login -method userpass username=<username>
```

### Secrets Engine

#### Enable KV Store (Version 2) 

>**NOTE:** Make sure that the path is covered in `kv-admins` policy

```bash
$ vault secrets enable -path=secret kv-v2
```

#### Secrets

```bash
$ vault kv put secret/laza pera=mika
$ vault kv get --format=json secret/laza | jq '.data.data'
$ vault kv list secret/
$ vault kv delete secret/laza
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

### Recreate Root Token

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