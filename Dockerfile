# Simple single Dockerfile for Railway deployment
FROM docker/compose:2.20.0

# Install additional tools
RUN apk add --no-cache curl postgresql-client

# Set working directory
WORKDIR /app

# Copy all necessary files
COPY . .

# Make scripts executable
RUN chmod +x manage-stack.sh start-stack.sh stop-stack.sh check-stack.sh

# Expose ports
EXPOSE 3000 3001 3002 8080 8081 8082 8083 9090 3100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8083/health || exit 1

# Start the entire stack
CMD ["./start-stack.sh"]