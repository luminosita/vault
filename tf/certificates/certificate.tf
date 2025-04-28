resource "vault_pki_secret_backend_cert" "example-dot-com" {
  issuer_ref  = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.intermediate_role.backend
  name        = vault_pki_secret_backend_role.intermediate_role.name
  common_name = "test.example.com"
  ttl         = 3600
  revoke     = true
}