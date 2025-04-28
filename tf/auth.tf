resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

# resource "vault_auth_backend" "approle" {
#   type = "approle"
# }

resource "vault_policy" "admin_policy" {
  name   = "admin_policy"
  policy = file("../config/policies/admin.hcl")
}
