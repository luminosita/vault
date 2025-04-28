resource "vault_pki_secret_backend_root_cert" "root_2024" {
  backend     = vault_mount.pki.path
  type        = "internal"
  common_name = "example.com"
  ttl         = "315360000"
  issuer_name = "root-2024"
  key_name    = "root_2024"
}

# used to update name and properties
# manages lifecycle of existing issuer
resource "vault_pki_secret_backend_issuer" "root_2024" {
  backend                        = vault_mount.pki.path
  issuer_ref                     = vault_pki_secret_backend_root_cert.root_2024.issuer_id
  issuer_name                    = vault_pki_secret_backend_root_cert.root_2024.issuer_name
  revocation_signature_algorithm = "SHA256WithRSA"
}

# vault write pki/roles/2024-servers allow_any_name=true
resource "vault_pki_secret_backend_role" "role_2024" {
  backend        = vault_mount.pki.path
  name           = "2024-servers"
  allow_any_name = true
}

# 8.1 - creates a new cross-signed intermediate CSR
# uses key from new root in step 7
# vault write -format=json pki/intermediate/cross-sign \
#       common_name="example.com" \
#       key_ref="$(vault read pki/issuer/root-2024 \
#       | grep -i key_id | awk '{print $2}')" \
#       | jq -r '.data.csr' \
#       | tee cross-signed-intermediate.csr
# pki/intermediate/cross-sign == pki/issuers/generate/intermediate/existing

resource "vault_pki_secret_backend_intermediate_cert_request" "new_csr" {
  backend     = vault_mount.pki.path
  type        = "existing"
  common_name = "example.com"
  key_ref     = vault_pki_secret_backend_root_cert.root_2024.key_name
}

## write to file
resource "local_file" "new_csr_file" {
  content  = vault_pki_secret_backend_intermediate_cert_request.new_csr.csr
  filename = "cross-signed-intermediate.csr"
}

# 8.2 - sign csr with older root CA
# vault write -format=json pki/issuer/root-2023/sign-intermediate \
#       common_name="example.com" \
#       csr=@cross-signed-intermediate.csr \
#       | jq -r '.data.certificate' | tee cross-signed-intermediate.crt

resource "vault_pki_secret_backend_root_sign_intermediate" "root_2024" {
  backend     = vault_mount.pki.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.new_csr.csr
  common_name = "example.com"
  ttl         = 43800
  issuer_ref  = vault_pki_secret_backend_root_cert.root_2023.issuer_id
}

# 8.3
# vault write pki/intermediate/set-signed \
#       certificate=@cross-signed-intermediate.crt

resource "vault_pki_secret_backend_intermediate_set_signed" "root_2024" {
  backend     = vault_mount.pki.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root_2024.certificate
}

# 8.4 - print 
# vault read pki/issuer/root-2024
output "vault_pki_secret_backend_root_sign_intermediate_root_2024_ca_chain" {
  value = vault_pki_secret_backend_root_sign_intermediate.root_2024.ca_chain
}

# # step 9
# # Set new default issuer
# resource "vault_pki_secret_backend_config_issuers" "config" {
#   backend                       = vault_mount.pki.path
#   default                       = vault_pki_secret_backend_issuer.root_2024.issuer_id
#   default_follows_latest_issuer = true
# }