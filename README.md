### Install Vault in Alpine LXC

#### Installation

```bash
$ sudo su -c "sh <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/scripts/install.sh) -n Noa -v 1.19.2" root
```

It will install Vault version 1.19.2 and create `raft` data node `Noa`

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

#### Add Policies

```bash
$ sh <(curl -L https://github.com/luminosita/vault/raw/refs/heads/main/scripts/setup.sh)
```

#### Add Admin User

```bash
$ vault write auth/userpass/users/admin password=<password> policies=admins
```

#### Add KV Admin User

```bash
$ vault write auth/userpass/users/<username> password=<password> policies=secret-admins
```

#### Revoke Root Token

```bash
vault token revoke <Root Token>
```

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