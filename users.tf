resource "vault_generic_endpoint" "cat_user" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/cat"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["cat_policy"],
  "password": "changeme"
}
EOT
}
