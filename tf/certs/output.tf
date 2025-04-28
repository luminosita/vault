output "ca_cert" {
  value = vault_pki_secret_backend_root_cert.ca.certificate
}

resource "local_file" "ca_cert" {
  content  = vault_pki_secret_backend_root_cert.ca.certificate
  filename = "output/ca.crt"
  file_permission = "0644"
}

resource "local_file" "csr_request_cert" {
  content  = vault_pki_secret_backend_intermediate_cert_request.vault.csr
  filename = "output/vault.csr"
  file_permission = "0644"
}

resource "local_file" "intermediate_ca_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.vault.certificate
  filename = "output/vault.cert.pem"
  file_permission = "0644"
}

resource "local_file" "cert" {
  content  = vault_pki_secret_backend_cert.vault-nodes.certificate
  filename = "output/${local.cert.name}.crt"
  file_permission = "0644"
}

resource "local_file" "issuing_ca" {
  content  = vault_pki_secret_backend_cert.vault-nodes.issuing_ca
  filename = "output/${local.cert.name}.ca"
  file_permission = "0644"
}

resource "local_file" "private_key" {
  content  = vault_pki_secret_backend_cert.vault-nodes.private_key
  filename = "output/${local.cert.name}.key"
  file_permission = "0644"
}


