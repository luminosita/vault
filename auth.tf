resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}