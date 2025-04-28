locals {
  ca = var.ca["root"]
}

resource "vault_mount" "pki_ca" {
  path        = "pki_ca"
  type        = "pki"
  description = local.ca.description

  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = local.ca.ttl
}

resource "vault_pki_secret_backend_root_cert" "ca" {
  backend     = vault_mount.pki_ca.path
  type        = "internal"
  common_name = local.ca.common_name
  ttl         = local.ca.ttl
  issuer_name = local.ca.issuer_name
}

resource "vault_pki_secret_backend_issuer" "ca" {
  backend                        = vault_mount.pki_ca.path
  issuer_ref                     = vault_pki_secret_backend_root_cert.ca.issuer_id
  issuer_name                    = vault_pki_secret_backend_root_cert.ca.issuer_name
  revocation_signature_algorithm = "SHA256WithRSA"
}

resource "vault_pki_secret_backend_role" "ca_vault" {
  backend          = vault_mount.pki_ca.path
  name             = local.ca.role_name
  ttl              = 86400
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = local.ca.allowed_domains
  allow_subdomains = true
  allow_any_name   = true
}

#FIXME: What are these URLS?
resource "vault_pki_secret_backend_config_urls" "config-urls" {
  backend                 = vault_mount.pki_ca.path
  issuing_certificates    = ["http://localhost:8200/v1/pki/ca"]
  crl_distribution_points = ["http://localhost:8200/v1/pki/crl"]
}
