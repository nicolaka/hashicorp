# Deploying vso helm chart
resource "helm_release" "vso" {
  name       = "vso"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = var.kubernetes_namespace
  version    = var.vso_helm_version

  set {
    name  = "defaultVaultConnection.enabled"
    value = "true"
  }

  set {
    name  = "defaultVaultConnection.address"
    value = var.vault_public_address
  }

  set {
    name  = "defaultVaultConnection.skipTLSVerify"
    value = "true"
  }
  
  set {
    name  = "defaultAuthMethod.enabled"
    value = "true"
  }

  set {
    name  = "defaultAuthMethod.namespace"
    value = var.vault_namespace
  }

  set {
    name  = "defaultAuthMethod.method"
    value = "kubernetes"
  }

  set {
    name  = "defaultAuthMethod.mount"
    value = "kubernetes"
  }

  set {
    name  = "defaultAuthMethod.kubernetes.role"
    value = "default"
  }

  set {
    name  = "defaultAuthMethod.kubernetes.serviceaccount"
    value = "default"
  }

  set_list {
    name  = "defaultAuthMethod.kubernetes.tokenAudiences"
    value = ["vault"]
  }
}

resource "vault_policy" "k8s_app_policy" {
  name = "k8s_app_policy"
  policy = <<EOT
# 
path "secret/data/app/config" {
  capabilities = ["read"]
}
EOT
}


resource "vault_kubernetes_auth_backend_role" "k8s_app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "default"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["default",var.kubernetes_namespace]
  token_ttl                        = 3600
  token_policies                   = ["k8s_app_policy"]
  audience                         = ""
}




