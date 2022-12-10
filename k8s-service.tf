resource "kubernetes_service" "web-service" {
  metadata {
    name = "web-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment.personal-website.spec.0.template.0.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
