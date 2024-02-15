

/* 
resource "kubernetes_config_map" "config" {

  metadata {
    name = "benchmark"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  data = {
    "benchmark.hcl" = file("benchmark.hcl")
  }
}

## Deploying Benchmark Job
resource "kubernetes_deployment" "benchmark" {
  depends_on = [ vault_namespace.blue ]
  metadata {
    name      = "benchmark"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      app = "benchmark"
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
        app = "benchmark"
      }
    }

    template {
      metadata {
        labels = {
          app = "benchmark"
        }
      }

      spec {
        container {
          image = "hashicorp/vault-benchmark"
          name  = "benchmark"
          command = ["vault-benchmark","run","-config=/opt/vault-benchmark/configs/benchmark.hcl"]
          volume_mount {
                mount_path = "/opt/vault-benchmark/configs/"
                name = "config"
            }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.config.metadata.0.name
          }

        }
      }
    }
  }
}
*/
