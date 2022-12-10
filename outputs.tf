output "load_balancer_ip" {
  value = kubernetes_service.web-service.status.0.load_balancer.0.ingress.0.hostname
}
