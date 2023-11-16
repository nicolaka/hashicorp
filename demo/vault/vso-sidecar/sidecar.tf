# Deploying sidecar injector helm chart
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = var.kubernetes_namespace
  version    = var.vault_helm_version

  set {
    name  = "injector.enabled"
    value = "true"
  }
  set {
    name  = "injector.logLevel"
    value = "debug"
  }
  set {
    name  = "injector.authPath"
    value = "auth/kubernetes"
  }
  set {
    name  = "global.externalVaultAddr"
    value = var.vault_public_address
  }
  set {
    name  = "global.tlsDisable"
    value = "true"
  }
  set {
    name  = "global.openshift"
    value = "true"
  }
}
