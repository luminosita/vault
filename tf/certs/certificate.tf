locals {
  cert = var.certs["vault_nodes"]
}

resource "vault_pki_secret_backend_cert" "vault-nodes" {
  issuer_ref  = vault_pki_secret_backend_issuer.vault.issuer_ref
  backend     = vault_pki_secret_backend_role.vault.backend
  name        = vault_pki_secret_backend_role.vault.name
  common_name = local.cert.common_name
  ip_sans     = local.cert.ip_sans
  ttl         = local.cert.ttl
  revoke      = true
}
