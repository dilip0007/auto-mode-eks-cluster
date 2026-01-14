
resource "kubernetes_ingress_class" "alb" {
  metadata {
    name = "alb"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    # This refers to the AWS Load Balancer Controller (or EKS Auto Mode's built-in one)
    controller = "ingress.k8s.aws/alb"
  }
}
