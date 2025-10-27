variable "access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "session_token" {
  description = "AWS session token"
  type        = string
  sensitive   = true
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region where all resources are provisioned."
}

variable "ubuntu_ami_id" {
  type        = string
  default     = "ami-0360c520857e3138f"
  description = "Ubuntu Server 22.04 LTS AMI to use for EC2 instances. Override if the default ID is not available in the target region."
}

variable "ssh_key_name" {
  type        = string
  description = "Existing EC2 key pair name used for SSH access to k3s nodes."
}

variable "admin_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR blocks allowed to reach the k3s control plane via SSH."
}

variable "k3s_server_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type for the k3s control-plane node."
}

variable "k3s_worker_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Instance type for the k3s worker nodes."
}

variable "k3s_worker_count" {
  type        = number
  default     = 2
  description = "Number of k3s worker nodes to provision."
}

variable "bastion_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Instance type for the bastion host used to SSH into private nodes."
}

variable "kubeconfig_path" {
  type        = string
  default     = ""
  description = "Local path to the kubeconfig file retrieved from the k3s server. Required before running the bootstrap step."
}

variable "db_user" {
  type        = string
  description = "Master username for the PostgreSQL instance."
}

variable "db_password" {
  type        = string
  description = "Master password for the PostgreSQL instance."
  sensitive   = true
}

variable "db_name" {
  type        = string
  default     = "bookstore"
  description = "Logical database name used by the application tier."
}

variable "rabbitmq_user" {
  type        = string
  default     = "user"
  description = "Username used by application services when connecting to RabbitMQ inside the cluster."
}

variable "rabbitmq_password" {
  type        = string
  default     = "password"
  description = "Password used by application services when connecting to RabbitMQ inside the cluster."
  sensitive   = true
}
