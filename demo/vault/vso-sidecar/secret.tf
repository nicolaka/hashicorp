resource "vault_mount" "kvv2" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount for static credential injection"
}

# Sample secrets 
resource "vault_kv_secret_v2" "app_secret" {
  mount                      = vault_mount.kvv2.path
  name                       = "app/config"
  cas                        = 1
  delete_all_versions        = true
  data_json                  = jsonencode(
  {
    username       = "demo",
    password       = "everythingisawesome"
  }
  )
}