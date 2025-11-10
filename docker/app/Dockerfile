# Multi-stage build for tiny runtime image
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod .
RUN go mod download || true
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/messaging-svc ./cmd/messaging-svc

# --- Runtime image
FROM alpine:3.20
RUN adduser -D -H -s /sbin/nologin appuser && apk add --no-cache ca-certificates curl
COPY --from=builder /out/messaging-svc /messaging-svc
USER appuser
EXPOSE 8080
ENV ADDR=:8080
ENTRYPOINT ["/messaging-svc"]
