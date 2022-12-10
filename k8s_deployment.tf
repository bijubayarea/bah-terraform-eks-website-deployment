resource "kubernetes_deployment" "personal-website" {
  metadata {
    name = "personal-website"
    labels = {
      app = "personal-website"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "personal-website"
      }
    }
    template {
      metadata {
        labels = {
          app = "personal-website"
        }
      }
      spec {


        container {
          image = "docker.io/bijubayarea/personal-website:v2.1"
          name  = "personal-website"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

        }
      }
    }
  }
}
