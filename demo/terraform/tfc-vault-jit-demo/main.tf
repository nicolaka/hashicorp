terraform {
  cloud {
    organization = "nico-tfc"

    workspaces {
      name = "hcp-vault-jit-demo"
    }
  }
}
provider "vault" {
}


data "vault_kv_secret_v2" "secret_data" {
  mount = "secret"
  name  = "secret"
}

output "vault_kv" {
  value     = nonsensitive(data.vault_kv_secret_v2.secret_data.data)
}

