resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig.yaml"

  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_ca_data  = data.aws_eks_cluster.app-cluster.certificate_authority[0].data
  })
}
