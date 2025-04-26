terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.8.0"
    }
  }
}

provider "vault" {
  address = var.vault_info.address
  token   = var.token
}
