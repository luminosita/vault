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

resource "vault_policy" "approle_admin_policy" {
  name   = "approle_admin_policy"
  policy = file("../config/policies/approle-admin.hcl")
}

resource "vault_policy" "kv_admin_policy" {
  name   = "kv_admin_policy"
  policy = file("../config/policies/kv-admin.hcl")
}
