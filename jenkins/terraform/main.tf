
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.8.138"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  wait    = false 
  timeout = 600

  values = [
    file("${path.module}/values.yaml")
  ]
}
