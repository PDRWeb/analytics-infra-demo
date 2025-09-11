FROM python:3.11-slim AS base

# Build argument to force rebuilds
ARG BUILD_DATE
ARG VCS_REF

# Install system dependencies including pandas requirements
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    libc6-dev \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

FROM base AS dependencies

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with compatibility fixes
RUN pip install --no-cache-dir --user --upgrade pip setuptools wheel
RUN pip install --no-cache-dir --user numpy==1.21.6
RUN pip install --no-cache-dir --user pandas==1.2.5
RUN pip install --no-cache-dir --user -r requirements.txt

FROM base AS production

WORKDIR /app

# Copy installed packages from dependencies stage
COPY --from=dependencies /root/.local /home/appuser/.local

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Add user's local bin to PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Set production environment
ENV ENVIRONMENT=production

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "data_validator.py"]
