variable vault_public_address {
  type        = string
  description = "Vault Address e.g https://vault.example.com" 
}

variable vault_namespace {
  type        = string
  description = "Vault Namespace" 
}

variable vault_admin_token {
  type        = string
  description = "Vault Token" 
}

variable kubernetes_endpoint {
  type        = string
  description = "Kubernetes/Openshift Endpoint" 
}

variable kubernetes_namespace {
  type        = string
  description = "Kubernetes Namespace" 
}

variable vault_helm_version {
  type        = string
  default = "0.26.1"
  description = "VSO Version" 
}

variable vso_helm_version {
  type        = string
  default = "0.3.1"
  description = "VSO Version" 
}








