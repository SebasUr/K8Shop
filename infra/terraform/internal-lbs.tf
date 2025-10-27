locals {
  worker_targets = { for idx, inst in aws_instance.k3s_worker : idx => inst.id }
}

resource "aws_lb" "catalog_internal" {
  name               = "bookstore-catalog-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  tags = {
    Project = "bookstore"
    Service = "catalog"
  }
}

resource "aws_lb_target_group" "catalog_internal" {
  name        = "tg-catalog-node"
  port        = local.k3s_node_ports["catalog"]
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    protocol = "HTTP"
    port     = local.k3s_node_ports["catalog"]
    path     = "/healthz"
  }
}

resource "aws_lb_listener" "catalog_internal" {
  load_balancer_arn = aws_lb.catalog_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalog_internal.arn
  }
}

resource "aws_lb_target_group_attachment" "catalog_internal" {
  for_each         = local.worker_targets
  target_group_arn = aws_lb_target_group.catalog_internal.arn
  target_id        = each.value
  port             = local.k3s_node_ports["catalog"]
}

resource "aws_lb" "cart_internal" {
  name               = "bookstore-cart-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  tags = {
    Project = "bookstore"
    Service = "cart"
  }
}

resource "aws_lb_target_group" "cart_internal" {
  name        = "tg-cart-node"
  port        = local.k3s_node_ports["cart"]
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    protocol = "HTTP"
    port     = local.k3s_node_ports["cart"]
    path     = "/healthz"
  }
}

resource "aws_lb_listener" "cart_internal" {
  load_balancer_arn = aws_lb.cart_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart_internal.arn
  }
}

resource "aws_lb_target_group_attachment" "cart_internal" {
  for_each         = local.worker_targets
  target_group_arn = aws_lb_target_group.cart_internal.arn
  target_id        = each.value
  port             = local.k3s_node_ports["cart"]
}

resource "aws_lb" "order_internal" {
  name               = "bookstore-order-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  tags = {
    Project = "bookstore"
    Service = "order"
  }
}

resource "aws_lb_target_group" "order_internal" {
  name        = "tg-order-node"
  port        = local.k3s_node_ports["order"]
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    protocol = "HTTP"
    port     = local.k3s_node_ports["order"]
    path     = "/healthz"
  }
}

resource "aws_lb_listener" "order_internal" {
  load_balancer_arn = aws_lb.order_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_internal.arn
  }
}

resource "aws_lb_target_group_attachment" "order_internal" {
  for_each         = local.worker_targets
  target_group_arn = aws_lb_target_group.order_internal.arn
  target_id        = each.value
  port             = local.k3s_node_ports["order"]
}
