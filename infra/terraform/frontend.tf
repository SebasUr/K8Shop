data "aws_lb" "catalog" {
  depends_on = [null_resource.k8s_bootstrap]
  tags = {
    "kubernetes.io/service-name" = "bookstore/catalog"
  }
}

data "aws_lb" "cart" {
  depends_on = [null_resource.k8s_bootstrap]
  tags = {
    "kubernetes.io/service-name" = "bookstore/cart"
  }
}

data "aws_lb" "order" {
  depends_on = [null_resource.k8s_bootstrap]
  tags = {
    "kubernetes.io/service-name" = "bookstore/order"
  }
}

resource "aws_security_group" "alb" {
  name   = "sg-alb-public"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "fe" {
  name   = "sg-frontend-ec2"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  catalog_api_base = format("http://%s", data.aws_lb.catalog.dns_name)
  cart_api_base    = format("http://%s", data.aws_lb.cart.dns_name)
  order_api_base   = format("http://%s", data.aws_lb.order.dns_name)
}

resource "aws_launch_template" "fe" {
  name_prefix   = "bookstore-fe-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  user_data = base64encode(<<EOF
                #!/bin/bash
        set -euo pipefail

  dnf install -y nginx git nodejs npm
                cat >/etc/nginx/nginx.conf <<'NGINX'
                events {}
                http {
                log_format json escape=json '{ "time":"$time_iso8601","req":"$request","status":$status,"len":$bytes_sent,"rt":"$request_time","rid":"$request_id" }';
                access_log /var/log/nginx/access.log json;
                server {
                        listen 8080;
                        root /usr/share/nginx/html;

            location / { try_files $uri /index.html; add_header Cache-Control "public, max-age=300" always; }
            location ~* \.(js|css|png|jpg|svg|woff2?)$ { add_header Cache-Control "public, max-age=31536000, immutable" always; try_files $uri =404; }

            location /api/catalog/ { proxy_pass ${local.catalog_api_base}/; }
            location /api/cart/    { proxy_pass ${local.cart_api_base}/; }
            location /api/orders/  { proxy_pass ${local.order_api_base}/; }

                        proxy_set_header X-Forwarded-For $remote_addr;
                        proxy_set_header X-Request-Id $request_id;
                        proxy_read_timeout 60s;
                }
                }
                NGINX
        rm -rf /usr/share/nginx/html/*

  rm -rf /opt/K8Shop
  mkdir -p /opt
  git clone https://github.com/SebasUr/K8Shop.git /opt/K8Shop
        cd /opt/K8Shop/frontend

        cat <<ENV > .env
VITE_CATALOG_API=${local.catalog_api_base}
VITE_CART_API=${local.cart_api_base}
VITE_ORDER_API=${local.order_api_base}
ENV

        npm install
        npm run build

        cp -r dist/* /usr/share/nginx/html/
                systemctl enable --now nginx
                EOF
  )
  vpc_security_group_ids = [aws_security_group.fe.id]
}

resource "aws_lb" "public" {
  name               = "bookstore-fe-alb"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "fe" {
  name     = "tg-fe-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/"
  }
}

resource "aws_autoscaling_group" "fe" {
  name                = "asg-fe"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.fe.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.fe.arn]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fe.arn
  }
}

