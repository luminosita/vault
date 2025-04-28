resource "vault_policy" "cat_policy" {
  name   = "cat_policy"
  policy = file("policies/cat-client-policy.hcl")
}
