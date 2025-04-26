vault policy write admins <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main
/policies/admins.hcl)
vault policy write terraform <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main
/policies/terraform.hcl)
vault policy write secret-admins <(wget -O - https://github.com/luminosita/vault/raw/refs/heads/main
/policies/kv-admins.hcl)