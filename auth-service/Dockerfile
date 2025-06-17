# GIAI ĐOẠN BUILD
FROM golang:1.20-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o /app .

# GIAI ĐOẠN CUỐI CÙNG
FROM alpine:3.18
RUN apk add --no-cache ca-certificates tzdata
RUN adduser -D -u 1000 -g '' appuser
WORKDIR /
COPY --from=builder /app /app
RUN chown appuser:appuser /app && chmod +x /app
USER appuser
EXPOSE 8080
ENV TZ=UTC
ENTRYPOINT ["/app"]