# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY . .

# Build the application
RUN go mod tidy
RUN go build -o /app ./main.go

# Stage 2: Create the final lean image
FROM alpine:latest

WORKDIR /

# Copy the executable from the builder stage
COPY --from=builder /app /app

# Ensure the executable has execute permissions
RUN chmod +x /app

# Set the entrypoint to run your application
ENTRYPOINT ["/app"]