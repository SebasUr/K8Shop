resource "aws_security_group" "alb" {
  name   = "bookstore-alb-sg"
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
  name   = "bookstore-frontend-ec2-sg"
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

locals {
  catalog_api_base = format("http://%s", aws_lb.catalog_internal.dns_name)
  cart_api_base    = format("http://%s", aws_lb.cart_internal.dns_name)
  order_api_base   = format("http://%s", aws_lb.order_internal.dns_name)
}

resource "aws_launch_template" "fe" {
  name_prefix   = "bookstore-fe-"
  image_id      = var.ubuntu_ami_id
  instance_type = "t3.micro"
  user_data = base64encode(<<EOF
                #!/bin/bash
        set -euo pipefail

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y nginx git curl ca-certificates
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
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

