#Vault login info. Use env VAULT_ADDR and VAULT_TOKEN as alternative
variable "vault" {
  type = object({
    endpoint = optional(string)
  })
}

variable "vault_token" {
  description = "API token for Vault"
  type        = string
  sensitive   = true
}

