module "certs" {
  source = "./certs"

  ca    = var.ca
  certs = var.certs
}
