# Monitoring Stack
# Deploying sidecar injector helm chart
resource "helm_release" "prometheus-community" {
  depends_on = [ helm_release.vault ]
  name       = "prometheus-community"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.vault.id
  #version    = var.vault_helm_version


  values = [
    "${file("prom.values.yml")}"
  ]
}

resource "kubernetes_secret_v1" "vault_token" {
  metadata {
    name = "vaulttoken"
    namespace  = kubernetes_namespace.vault.id
  }

  data = {
    token = var.vault_admin_token
  }

  type = "kubernetes.io/opaque"
}
