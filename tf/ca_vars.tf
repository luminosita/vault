variable "ca" {
  type = map(object({
    issuer          = string
    issuer_name     = optional(string)
    common_name     = string
    role_name       = string
    allowed_domains = list(string)
    description     = optional(string)
  }))
}

variable "certs" {
  type = map(object({
    name        = string
    common_name = string
  }))
}
