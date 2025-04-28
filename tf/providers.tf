terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.8.0"
    }
  }
}

provider "vault" {
  address         = var.vault.endpoint
  token           = var.vault.token
  skip_tls_verify = true   # FIXME: replace with proper certificate
}
