module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true # DEMO
  cluster_endpoint_private_access = true # DEMO

  eks_managed_node_groups = {
    general = {
      desired_size   = var.desired
      min_size       = var.min
      max_size       = var.max
      instance_types = [var.node_type]
      subnets        = module.vpc.private_subnets
    }
  }
}
