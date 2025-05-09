# Write and manage secrets in key-value secrets engine
path "secret*" {
  capabilities = [ "create", "read", "update", "delete", "list", "patch" ]
}

# To enable secrets engines
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete" ]
}
