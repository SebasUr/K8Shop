package main

import (
  "encoding/json"
  "log"
  "math/rand"
  "os"
  "os/signal"
  "syscall"
  "time"

  amqp "github.com/rabbitmq/amqp091-go"
)

type OrderCreated struct {
  Event         string        `json:"event"`
  Version       int           `json:"version"`
  OrderId       string        `json:"orderId"`
  UserId        string        `json:"userId"`
  Items         []interface{} `json:"items"`
  Total         float64       `json:"total"`
  MessageId     string        `json:"messageId"`
  CorrelationId string        `json:"correlationId"`
}

func failOnError(err error, msg string) {
  if err != nil {
    log.Fatalf("%s: %s", msg, err)
  }
}

func main() {
  rand.Seed(time.Now().UnixNano())
  url := os.Getenv("RABBIT_URL")
  if url == "" { url = "amqp://user:pass@rabbitmq:5672/" }

  conn, err := amqp.Dial(url)
  failOnError(err, "Failed to connect to RabbitMQ")
  defer conn.Close()

  ch, err := conn.Channel()
  failOnError(err, "Failed to open a channel")
  defer ch.Close()

  err = ch.ExchangeDeclare("orders", "topic", true, false, false, false, nil)
  failOnError(err, "Exchange declare")

  q, err := ch.QueueDeclare("payment.queue", true, false, false, false, amqp.Table{"x-dead-letter-exchange": "orders.dlq"})
  failOnError(err, "Queue declare")

  err = ch.QueueBind(q.Name, "orders.order_created", "orders", false, nil)
  failOnError(err, "Queue bind")

  msgs, err := ch.Consume(q.Name, "", false, false, false, false, nil)
  failOnError(err, "Consume")

  // graceful shutdown
  sigs := make(chan os.Signal, 1)
  signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

  go func() {
    for d := range msgs {
      var evt OrderCreated
      if err := json.Unmarshal(d.Body, &evt); err != nil {
        log.Println("bad message", err)
        d.Nack(false, false)
        continue
      }
      log.Printf("[payment] received order %s total=%v", evt.OrderId, evt.Total)
      time.Sleep(1500 * time.Millisecond) // simulate latency
      success := rand.Float32() > 0.1
      var out map[string]interface{}
      routing := "orders.payment_succeeded"
      if success {
        out = map[string]interface{}{"event":"payment.succeeded","orderId":evt.OrderId,"amount":evt.Total,"txId":"tx-"+evt.MessageId,"messageId":"pay-"+evt.MessageId,"correlationId":evt.CorrelationId}
      } else {
        routing = "orders.payment_failed"
        out = map[string]interface{}{"event":"payment.failed","orderId":evt.OrderId,"reason":"card_declined","messageId":"pay-"+evt.MessageId,"correlationId":evt.CorrelationId}
      }
      body, _ := json.Marshal(out)
      err = ch.Publish("orders", routing, false, false, amqp.Publishing{ContentType:"application/json", DeliveryMode: 2, Body: body, MessageId: out["messageId"].(string), CorrelationId: evt.CorrelationId})
      if err != nil {
        log.Println("publish error", err)
        d.Nack(false, true)
        continue
      }
      d.Ack(false)
      log.Printf("[payment] published %s for order %s", out["event"], evt.OrderId)
    }
  }()

  <-sigs
  log.Println("shutting down payment")
}
