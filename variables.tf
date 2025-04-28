variable "vault" {
  type = object({
    token    = string
    endpoint = string
  })
}
