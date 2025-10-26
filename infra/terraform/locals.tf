locals {
  rabbitmq_internal_host = "rabbitmq.bookstore.svc.cluster.local"
  rabbitmq_url           = format("amqp://%s:%s@%s:5672/", var.rabbitmq_user, var.rabbitmq_password, local.rabbitmq_internal_host)
  redis_host             = aws_elasticache_replication_group.redis.primary_endpoint_address
  cart_redis_url         = format("rediss://%s:6379/0", local.redis_host)
}
