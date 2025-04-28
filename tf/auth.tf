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

resource "vault_generic_endpoint" "admin_user" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = jsonencode({
    policies = [ "admin_policy" ]
    password = var.admin_password
  })
}