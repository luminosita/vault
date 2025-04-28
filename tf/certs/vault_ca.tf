locals {
  vault = var.ca["vault"]
}

resource "vault_mount" "pki_vault" {
  path        = "pki_vault"
  type        = "pki"
  description = local.vault.description

  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = local.ca.ttl
}

resource "vault_pki_secret_backend_intermediate_cert_request" "vault" {
  backend     = vault_mount.pki_vault.path
  type        = "internal"
  common_name = local.vault.common_name
}

resource "vault_pki_secret_backend_root_sign_intermediate" "vault" {
  backend     = vault_mount.pki_ca.path
  common_name = local.vault.common_name
  csr         = vault_pki_secret_backend_intermediate_cert_request.vault.csr
  format      = "pem_bundle"
  ttl         = local.ca.ttl
  issuer_ref  = vault_pki_secret_backend_root_cert.ca.issuer_id
}

resource "vault_pki_secret_backend_intermediate_set_signed" "vault" {
  backend     = vault_mount.pki_vault.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.vault.certificate
}

resource "vault_pki_secret_backend_issuer" "vault" {
  backend     = vault_mount.pki_vault.path
  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.vault.imported_issuers[0]
  issuer_name = local.vault.issuer_name
}

resource "vault_pki_secret_backend_role" "vault" {
  backend          = vault_mount.pki_vault.path
  issuer_ref       = vault_pki_secret_backend_issuer.vault.issuer_ref
  name             = local.vault.role_name
  ttl              = 86400
  max_ttl          = local.vault.role_ttl
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = local.vault.allowed_domains
  allow_subdomains = true
}
