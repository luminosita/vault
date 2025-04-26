### Install Vault in Alpine LXC

#### Installation

```bash
$ sudo su -c "sh <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) -n Noa -v 1.19.2" root
```

It will install Vault version 1.19.2 and create `raft` data node `Noa`

#### Initial Setup

```bash
$ export VAULT_ADDR="https://$(ip a show dev eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'):8200"
$ export VAULT_SKIP_VERIFY=true
$ vault operator init -key-shares=1 -key-threshold=1
$ vault operator unseal
Unseal Key (will be hidden): <Unseal Key 1>
```

#### Login

```bash
$ vault login
Token (will be hidden): <root token>
```

#### Add Policies

```bash
$ vault policy write admins <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main
/policies/admins.hcl)
$ vault policy write terraform ./terraform.hcl
$ vault policy write secret-admins ./secret-admins.hcl
```

vault auth enable userpass
vault write auth/userpass/users/admin password=*** policies=admins
vault write auth/userpass/users/milosh password=*** policies=secret-admins

vault token revoke s.5uR1xpJvf6v33do9zPgjrTjC

vault secrets enable -path=secret kv-v2

vault read auth/userpass/users/milosh

As user:
vault login -method userpass username=milosh

vault kv put secret/laza pera=mika
vault kv get --format=json secret/laza
vault kv list secret/

Recreate root token:

vault operator generate-root -init
vault operator generate-root -otp="***"
vault operator generate-root -decode=*** -otp ***