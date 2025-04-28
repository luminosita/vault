### Install Vault in Alpine LXC

#### Vault Temp Server

```bash
$ sudo su -c "bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) dev" root
```

, to specify Vault and Terraform versions use

```bash
$ sudo su -c "TERRAFORM_VERSION=1.11.3 VAULT_VERSION=1.19.2 bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) dev" root
```

#### Vault Servers

For each cluster node

```bash
$ sudo su -c "bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) create -n Noa -p https://172.16.20.12:8200 -p https://172.16.20.13:8200" root
```

It will install clustered Vault server and create `raft` data node `Noa`

#### Unseal Servers

```bash
$ sudo su -c "bash <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) setup" root
```

### Terraform

```bash
$ export VAULT_CACERT=
$ export VAULT_ADDR=
$ export VAULT_TOKEN=
$ make init
$ vault token revoke <Root Token>
```







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