resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

locals {
  k3s_node_ports = {
    catalog = 31080
    cart    = 31081
    order   = 31082
  }
}

resource "aws_security_group" "k3s" {
  name        = "bookstore-k3s"
  description = "Security group for k3s control-plane and workers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from admin CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "SSH between k3s nodes"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Admin kube-apiserver access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Kubelet metrics"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "bookstore"
    Role    = "k3s"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bookstore-bastion"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from admin CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "bookstore"
    Role    = "bastion"
  }
}

resource "aws_instance" "k3s_server" {
  ami                         = var.ubuntu_ami_id
  instance_type               = var.k3s_server_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.k3s.id]

  user_data = templatefile("${path.module}/templates/k3s-server.sh.tpl", {
    token = random_password.k3s_token.result
  })

  tags = {
    Name    = "bookstore-k3s-server"
    Project = "bookstore"
    Role    = "k3s-server"
  }
}

resource "aws_instance" "k3s_worker" {
  count                       = var.k3s_worker_count
  ami                         = var.ubuntu_ami_id
  instance_type               = var.k3s_worker_instance_type
  subnet_id                   = element(module.vpc.private_subnets, count.index % length(module.vpc.private_subnets))
  associate_public_ip_address = false
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.k3s.id]

  user_data = templatefile("${path.module}/templates/k3s-agent.sh.tpl", {
    token              = random_password.k3s_token.result
    server_private_ip = aws_instance.k3s_server.private_ip
  })

  tags = {
    Name    = "bookstore-k3s-worker-${count.index}"
    Project = "bookstore"
    Role    = "k3s-worker"
  }
}

resource "aws_security_group_rule" "k3s_ssh_from_bastion" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = aws_security_group.bastion.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from bastion to k3s nodes"
}

resource "aws_instance" "bastion" {
  ami                         = var.ubuntu_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  tags = {
    Name    = "bookstore-bastion"
    Project = "bookstore"
    Role    = "bastion"
  }
}

resource "null_resource" "wait_for_k3s" {
  depends_on = [aws_instance.k3s_worker]

  provisioner "local-exec" {
    command = "echo 'k3s instances created. Retrieve kubeconfig from the server to proceed.'"
  }
}
