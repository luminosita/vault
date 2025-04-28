resource "vault_pki_secret_backend_cert" "example-dot-com" {
  issuer_ref  = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.intermediate_role.backend
  name        = vault_pki_secret_backend_role.intermediate_role.name
  common_name = "test.example.com"
  ttl         = 3600
  revoke     = true
}

resource "local_file" "cert" {
  content  = vault_pki_secret_backend_cert.example-dot-com.certificate
  filename = "example-dot-com.crt"
}

resource "local_file" "issuing_ca" {
  content  = vault_pki_secret_backend_cert.example-dot-com.issuing_ca
  filename = "example-dot-com.ca"
}

resource "local_file" "private_key" {
  content  = vault_pki_secret_backend_cert.example-dot-com.private_key
  filename = "example-dot-com.key"
}
