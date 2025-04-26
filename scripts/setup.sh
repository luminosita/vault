#Add policies
vault policy write admins <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/policies/admins.hcl)
vault policy write terraform <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/policies/terraform.hcl)
vault policy write kv-admins <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main/policies/kv-admins.hcl)

#Enable userpass authentication method
vault auth enable userpass


