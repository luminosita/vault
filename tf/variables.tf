#Vault login info. Use env VAULT_ADDR and VAULT_TOKEN as alternative
variable "vault" {
  type = object({
    token    = optional(string)
    endpoint = optional(string)
  })
}

variable "admin_username" {
  type = optional(string, "admin")
}

variable "admin_password" {
  type = string
}