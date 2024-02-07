# Deploying Vault Helm Chart, VSO, LDAP 
# Creating Vault Enterprise License Secret
resource "kubernetes_secret_v1" "vault_license" {
  metadata {
    name = "vaultlicense"
    namespace  = kubernetes_namespace.vault.id
  }

  data = {
    license = var.vault_license
  }

  type = "kubernetes.io/opaque"
}


# Deploying sidecar injector helm chart
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.id
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
    name  = "global.tlsDisable"
    value = "true"
  }
  set {
    name = "server.dev.enabled"
    value ="true"
  }
  set {
    name = "server.enterpriseLicense.secretName"
    value ="vaultlicense"
  }
  set {
    name = "server.enterpriseLicense.secretKey"
    value ="license"
  }
  set {
    name = "server.image.repository"
    value ="hashicorp/vault-enterprise"
  }
  set {
    name = "server.image.tag"
    value = var.vault_version
  }
  set {
    name = "server.logLevel"
    value = "trace"
  }
  set {
    name = "ui.enabled"
    value ="true"
  }
  set {
    name = "ui.serviceType"
    value ="NodePort"
  }
  set {
    name = "ui.serviceNodePort"
    value ="30001"
  }
}

# Deploying VSO
resource "helm_release" "vso" {
  depends_on = [ helm_release.vault ]
  name       = "vso"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = kubernetes_namespace.vault.id
  version    = var.vso_helm_version

  set {
    name  = "defaultVaultConnection.enabled"
    value = "true"
  }

  set {
    name  = "defaultVaultConnection.address"
    value = "http://${data.kubernetes_service.vault.spec.0.cluster_ip}:8200"
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

# VSO Kuberneters Connections

resource "kubernetes_manifest" "blue-vault-connection-default" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.blue.metadata[0].name
    }
    spec = {
      address = "http://vault.vault.svc.cluster.local:8200"
    }
  }

  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "blue-vault-auth-default" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.blue.metadata[0].name
    }
    spec = {
      method    = "kubernetes"
      namespace = vault_auth_backend.kubernetes.namespace
      mount     = vault_auth_backend.kubernetes.path
      kubernetes = {
        role           = vault_kubernetes_auth_backend_role.app_a.role_name
        serviceAccount = "default"
        audiences = [
          "vault",
        ]
      }
    }
  }
}

## Deploying LDAP 
resource "kubernetes_deployment" "ldap" {
  metadata {
    name      = "ldap"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      app = "ldap"
    }
  }


  spec {
    replicas = 1

    strategy {
      rolling_update {
        max_unavailable = "1"
      }
    }

    selector {
      match_labels = {
        app = "ldap"
      }
    }

    template {
      metadata {
        labels = {
          app = "ldap"
        }
      }

      spec {
        container {
          image = "nicolaka/samba-domain:1.0"
          name  = "ldap"

          env {
            name = "DOMAIN"
            value = "hashicorp.com"
          }
          env {
            name = "DOMAINPASS"
            value = "P@ssword1"
          }

          env {
            name = "INSECURELDAP"
            value = "true"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ldap" {
  metadata {
    name = "ldap"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  spec {
    selector = {
      app = "ldap"
    }
    session_affinity = "ClientIP"
    port {
      name        = "ldap-389"
      port        = 389
      target_port = 389
    }

    port {
      name        = "ldap-636"
      port        = 636
      target_port = 636
    }

    type = "ClusterIP"  
  }
}


