
# nodepools.tf

# 1. We "render" the template file with real values from our EKS module
resource "local_file" "node_config_final" {
  content = templatefile("${path.module}/configs/node-config.yaml.tmpl", {
    REPLACEME_CLUSTER_NAME       = var.cluster_name
    REPLACEME_NODE_ROLE_NAME     = module.eks.node_iam_role_name
    REPLACEME_SECURITY_GROUP_ID  = module.eks.cluster_primary_security_group_id
  })
  filename = "${path.module}/configs/node-config.yaml"
}

# 2. We use local-exec to apply that finished file
resource "null_resource" "apply_nodepool" {
  # This makes sure the command only runs AFTER the cluster and the YAML file are ready
  depends_on = [module.eks, local_file.node_config_final]

  triggers = {
    # If the contents of the final YAML file change, re-run the apply
    manifest_sha1 = sha1(local_file.node_config_final.content)
  }

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}
      kubectl apply -f ${local_file.node_config_final.filename}
    EOT
  }
}
