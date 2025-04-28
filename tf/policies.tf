resource "vault_policy" "cat_policy" {
  name   = "cat_policy"
  policy = file("../config/policies/cat-client-policy.hcl")
}
