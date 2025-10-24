FROM golang:1.20-alpine AS build
WORKDIR /src
COPY . .
RUN go build -o /bin/payment

FROM alpine:3.18
COPY --from=build /bin/payment /payment
ENV RABBIT_URL=amqp://user:pass@rabbitmq:5672/
CMD ["/payment"]
