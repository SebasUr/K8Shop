# API Endpoints

### Catalog Service
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/products` | List all products | No |
| GET | `/products/:id` | Get product details | No |
| POST | `/products` | Create new product | Yes (Admin) |
| PUT | `/products/:id` | Update product | Yes (Admin) |
| DELETE | `/products/:id` | Delete product | Yes (Admin) |
| GET | `/healthz` | Health check | No |

**gRPC Service:**
- `GetProduct(id)` → ProductDetails
- `ListProducts(filter)` → ProductList

### Cart Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/cart/:userId` | Get user's cart |
| POST | `/cart/:userId/items` | Add item to cart |
| PUT | `/cart/:userId/items/:productId` | Update item quantity |
| DELETE | `/cart/:userId/items/:productId` | Remove item from cart |
| DELETE | `/cart/:userId` | Clear cart |
| GET | `/healthz` | Health check |

### Order Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/orders` | Create new order from cart |
| GET | `/orders/:orderId` | Get order details |
| GET | `/orders/user/:userId` | List user's orders |
| PUT | `/orders/:orderId/status` | Update order status |
| GET | `/healthz` | Health check |

### Payment Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payments` | Process payment for order |
| GET | `/payments/:paymentId` | Get payment status |
| POST | `/payments/:paymentId/refund` | Refund payment |
| GET | `/healthz` | Health check |

### Inventory Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/inventory/:sku` | Get stock level |
| POST | `/inventory/:sku/reserve` | Reserve stock for order |
| POST | `/inventory/:sku/release` | Release reserved stock |
| PUT | `/inventory/:sku` | Update stock level |
| GET | `/healthz` | Health check |

### Recommendation Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/recommendations/:userId` | Get personalized recommendations |
| GET | `/recommendations/product/:productId` | Get similar products |
| GET | `/healthz` | Health check |

### Notification Service
*No HTTP endpoints - consumes RabbitMQ events only*
- Listens to: `order.created`, `payment.processed`, `order.shipped`

# Event-Driven Architecture

### RabbitMQ Exchanges and Queues

| Exchange | Type | Routing Key Pattern | Description |
|----------|------|---------------------|-------------|
| `bookstore.events` | topic | `*.created`, `*.updated` | Main event bus |
| `bookstore.dlx` | topic | `*.failed` | Dead Letter Exchange for failed messages |

### Published Events

| Service | Event | Routing Key | Payload |
|---------|-------|-------------|---------|
| catalog-service | Product Created | `product.created` | `{id, sku, title, price}` |
| catalog-service | Product Updated | `product.updated` | `{id, sku, changes}` |
| order-service | Order Created | `order.created` | `{orderId, userId, items[], total}` |
| order-service | Order Confirmed | `order.confirmed` | `{orderId, status}` |
| payment-service | Payment Processed | `payment.processed` | `{paymentId, orderId, amount, status}` |
| payment-service | Payment Failed | `payment.failed` | `{paymentId, orderId, reason}` |
| inventory-service | Stock Updated | `inventory.updated` | `{sku, quantity, reserved}` |
| inventory-service | Stock Low | `inventory.low` | `{sku, threshold, current}` |

### Consumed Events

| Service | Listens To | Action |
|---------|------------|--------|
| notification-service | `order.created`, `payment.processed`, `order.shipped` | Send email/SMS notifications |
| inventory-service | `order.created` | Reserve stock for order items |
| inventory-service | `payment.failed` | Release reserved stock |
| order-service | `payment.processed` | Update order status to confirmed |
| order-service | `payment.failed` | Update order status to payment_failed |

### Message Reliability
- **Acknowledgment Mode**: Manual ACK (at-least-once delivery)
- **Prefetch Count**: 10 messages per consumer
- **Dead Letter Queue**: Failed messages routed to DLX after 3 retries
- **Message TTL**: 24 hours for unprocessed messages