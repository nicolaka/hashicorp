path "secret/*" {
  capabilities = ["list"]
}
path "secret/engineering/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "/aws/creds/engineering" {
  capabilities = ["read"]
}
