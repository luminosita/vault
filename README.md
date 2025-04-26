### Install Vault in Alpine LXC

#### Installation script




As root:
vault operator init
vault operator unseal

vault policy write admins ./vault-admins.hcl
vault policy write secret-admins ./secret-admins.hcl

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