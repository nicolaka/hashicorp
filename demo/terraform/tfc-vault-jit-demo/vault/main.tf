resource "vault_jwt_auth_backend" "tfc-jwt" {
    path                = "jwt"
    oidc_discovery_url  = "https://app.terraform.io"
    bound_issuer        = "https://app.terraform.io"
}

resource "vault_jwt_auth_backend_role" "tfc-role" {
  backend         = vault_jwt_auth_backend.tfc-jwt.path
  role_name       = "tfc-role"
  token_policies  = ["tfc-policy"]

  bound_audiences = ["vault.workload.identity"]
  bound_claims_type = "glob"
  bound_claims = {
    sub = "organization:YOUR_TFC_ORK_NAME:workspace:YOUR_TFC_WORKSPACE_NAME:run_phase:*"
  }
  user_claim      = "terraform_full_workspace"
  role_type       = "jwt"
}

resource "vault_policy" "tfc-policy" {
  name = "tfc-policy"

  policy = <<EOT
# Used to generate child tokens in vault
path "auth/token/create" {
  capabilities = ["update"]
}
# Used by the token to query itself
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
# Actual secrets the token should have access to
path "secret/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_mount" "secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_kv_secret_v2" "secret" {
  mount                      = vault_mount.secret.path
  name                       = "secret"
  cas                        = 1
  delete_all_versions        = true
  data_json                  = jsonencode(
  {
    zip       = "zap",
    foo       = "bar"
  }
  )
}