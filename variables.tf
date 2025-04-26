variable "token" {
  type = string
}

variable "vault_info" {
  type = object({
    address = string 
  })
}