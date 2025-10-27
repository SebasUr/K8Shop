output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs used by backend services and k3s workers."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the VPC hosting the workload."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs used by edge resources (k3s server, ALB)."
}

output "k3s_server_public_ip" {
  value       = aws_instance.k3s_server.public_ip
  description = "Public IP of the k3s control-plane node. SSH here to retrieve kubeconfig."
}

output "k3s_server_private_ip" {
  value       = aws_instance.k3s_server.private_ip
  description = "Private IP of the k3s control-plane node used by workers."
}

output "k3s_worker_private_ips" {
  value       = [for inst in aws_instance.k3s_worker : inst.private_ip]
  description = "Private IPs of k3s worker nodes registered behind the internal load balancers."
}

output "k3s_security_group_id" {
  value       = aws_security_group.k3s.id
  description = "Security group protecting the k3s nodes."
}

output "k3s_kubeconfig_note" {
  value       = "SSH to ubuntu@${aws_instance.k3s_server.public_ip} using key '${var.ssh_key_name}', then copy /home/ubuntu/kubeconfig locally and set TF_VAR_kubeconfig_path before running the bootstrap."
  description = "Instructional note for obtaining the kubeconfig."
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP address of the bastion host for SSH access to private subnets."
}

output "rds_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "Hostname for the PostgreSQL RDS instance."
}

output "redis_primary_endpoint" {
  value       = local.redis_host
  description = "Primary endpoint for the ElastiCache Redis replication group."
}

output "dynamodb_table" {
  value       = aws_dynamodb_table.inventory.name
  description = "Name of the DynamoDB table backing inventory state."
}

output "frontend_url" {
  value       = aws_lb.public.dns_name
  description = "Public DNS name for the front-end ALB."
}

output "catalog_internal_dns" {
  value       = aws_lb.catalog_internal.dns_name
  description = "Internal NLB forwarding to the catalog-service NodePort."
}

output "cart_internal_dns" {
  value       = aws_lb.cart_internal.dns_name
  description = "Internal NLB forwarding to the cart-service NodePort."
}

output "order_internal_dns" {
  value       = aws_lb.order_internal.dns_name
  description = "Internal NLB forwarding to the order-service NodePort."
}

output "rabbitmq_url" {
  value       = local.rabbitmq_url
  sensitive   = true
  description = "Internal RabbitMQ URL injected into microservices via ConfigMaps."
}

output "cart_redis_url" {
  value       = local.cart_redis_url
  description = "Redis URL used by the cart-service."
}
