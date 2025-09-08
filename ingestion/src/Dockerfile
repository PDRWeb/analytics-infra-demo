FROM python:3.11-slim

WORKDIR /app/src

# Install system dependencies including Postgres client
RUN apt-get update && apt-get install -y postgresql-client curl && rm -rf /var/lib/apt/lists/*

# Copy API code and wait script
COPY . .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Make wait script executable
RUN chmod +x wait-for-db.sh

# Default command (can be overridden in docker-compose)
CMD ["python", "api_receiver.py"]
