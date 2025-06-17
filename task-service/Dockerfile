# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder

WORKDIR /src

COPY . .

RUN go mod tidy
RUN CGO_ENABLED=0 go build -o /build/my-app ./main.go
RUN chmod +x /build/my-app


# Stage 2: Create the final lean image
FROM alpine:latest

WORKDIR /

COPY --from=builder /build/my-app /app

ENTRYPOINT ["/app"]