# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 19.20"

#   cluster_name    = var.cluster_name
#   cluster_version = "1.29" # (1.30 puede no estar soportado en v19)
#   vpc_id          = module.vpc.vpc_id
#   subnet_ids      = module.vpc.private_subnets

#   # Evitar toques IAM (si tuvieras roles preexistentes)
#   create_iam_role      = false
#   # iam_role_arn       = "arn:aws:iam::<acct>:role/eks-cluster-role"   # si lo tienes
#  # manage_aws_auth      = false  # v19 usa aws-auth submodule
#   # Para los nodegroups:
#   eks_managed_node_groups = {
#     general = {
#       desired_size  = var.desired
#       min_size      = var.min
#       max_size      = var.max
#       instance_types = [var.node_type]
#       subnet_ids     = module.vpc.private_subnets
#       # create_iam_role = false
#       # iam_role_arn    = "arn:aws:iam::<acct>:role/eks-node-role"
#     }
#   }
# }
