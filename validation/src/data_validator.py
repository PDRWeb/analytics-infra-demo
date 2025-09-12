import os
import json
import time
import logging
import psycopg2
from datetime import datetime
from typing import Dict, List, Any, Optional
from flask import Flask, jsonify, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from pydantic import BaseModel, ValidationError
import jsonschema

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Prometheus metrics - check if already registered to avoid Gunicorn worker conflicts
from prometheus_client import REGISTRY

def get_or_create_counter(name, description, labelnames=None):
    """Get existing counter or create new one to avoid duplicate registration"""
    # Check if metric already exists by trying to find it in the registry
    for collector in REGISTRY._names_to_collectors.values():
        if hasattr(collector, 'name') and collector.name == name:
            return collector
    
    # Handle None labelnames for counters - ensure it's always a list
    if labelnames is None:
        labelnames = []
    # Additional safety check - ensure labelnames is iterable
    if not isinstance(labelnames, (list, tuple)):
        labelnames = []
    
    try:
        return Counter(name, description, labelnames=labelnames)
    except ValueError:
        # If it still fails, try to find and return existing metric
        for collector in REGISTRY._names_to_collectors.values():
            if hasattr(collector, 'name') and collector.name == name:
                return collector
        raise

def get_or_create_histogram(name, description, labelnames=None):
    """Get existing histogram or create new one to avoid duplicate registration"""
    # Check if metric already exists by trying to find it in the registry
    for collector in REGISTRY._names_to_collectors.values():
        if hasattr(collector, 'name') and collector.name == name:
            return collector
    
    # Handle None labelnames for histograms - ensure it's always a list
    if labelnames is None:
        labelnames = []
    # Additional safety check - ensure labelnames is iterable
    if not isinstance(labelnames, (list, tuple)):
        labelnames = []
    
    try:
        return Histogram(name, description, labelnames=labelnames)
    except ValueError:
        # If it still fails, try to find and return existing metric
        for collector in REGISTRY._names_to_collectors.values():
            if hasattr(collector, 'name') and collector.name == name:
                return collector
        raise

def get_or_create_gauge(name, description):
    """Get existing gauge or create new one to avoid duplicate registration"""
    # Check if metric already exists by trying to find it in the registry
    for collector in REGISTRY._names_to_collectors.values():
        if hasattr(collector, 'name') and collector.name == name:
            return collector
    
    try:
        return Gauge(name, description)
    except ValueError:
        # If it still fails, try to find and return existing metric
        for collector in REGISTRY._names_to_collectors.values():
            if hasattr(collector, 'name') and collector.name == name:
                return collector
        raise

# Initialize metrics safely
validation_total = get_or_create_counter('validation_total', 'Total validations', ['status', 'schema_type'])
validation_errors = get_or_create_counter('validation_errors_total', 'Total validation errors', ['error_type'])
validation_duration = get_or_create_histogram('validation_duration_seconds', 'Time spent validating data', [])
dlq_size = get_or_create_gauge('dead_letter_queue_size', 'Number of records in dead letter queue')
data_quality_score = get_or_create_gauge('data_quality_score', 'Overall data quality score (0-100)')

# Database configuration
HOLDING_DB = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASS"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT", 5432),
}

DLQ_DB = {
    "dbname": os.getenv("DLQ_DB_NAME"),
    "user": os.getenv("DLQ_DB_USER"),
    "password": os.getenv("DLQ_DB_PASS"),
    "host": os.getenv("DLQ_DB_HOST"),
    "port": 5432,
}

# Data schemas
SALES_SCHEMA = {
    "type": "object",
    "properties": {
        "sale_id": {"type": "string", "pattern": "^S[0-9]+$"},
        "sale_date": {"type": "string", "format": "date-time"},
        "customer_id": {"type": "integer", "minimum": 1},
        "item_id": {"type": "integer", "minimum": 1},
        "item_name": {"type": "string", "minLength": 1},
        "quantity": {"type": "integer", "minimum": 1},
        "unit_price": {"type": "number", "minimum": 0.01},
        "total_price": {"type": "number", "minimum": 0.01}
    },
    "required": ["sale_id", "sale_date", "customer_id", "item_id", "item_name", "quantity", "unit_price", "total_price"],
    "additionalProperties": False
}

# Pydantic models for additional validation
class SaleData(BaseModel):
    sale_id: str
    sale_date: datetime
    customer_id: int
    item_id: int
    item_name: str
    quantity: int
    unit_price: float
    total_price: float

    def validate_total_price(self):
        """Validate that total_price equals quantity * unit_price"""
        expected_total = self.quantity * self.unit_price
        if abs(self.total_price - expected_total) > 0.01:  # Allow for floating point precision
            raise ValueError(f"Total price {self.total_price} doesn't match quantity * unit_price ({expected_total})")

def get_conn(config):
    """Get database connection"""
    try:
        return psycopg2.connect(**config)
    except psycopg2.Error as e:
        logger.error(f"Failed to connect to database: {e}")
        raise

def init_dlq_tables():
    """Initialize dead letter queue tables"""
    try:
        conn = get_conn(DLQ_DB)
        cur = conn.cursor()
        
        cur.execute("""
        CREATE TABLE IF NOT EXISTS failed_validations (
            id SERIAL PRIMARY KEY,
            original_data JSONB NOT NULL,
            validation_errors JSONB NOT NULL,
            schema_type VARCHAR(50),
            failed_at TIMESTAMP DEFAULT NOW(),
            retry_count INTEGER DEFAULT 0,
            last_retry_at TIMESTAMP
        );
        """)
        
        cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_failed_validations_schema_type ON failed_validations(schema_type);
        """)
        
        cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_failed_validations_failed_at ON failed_validations(failed_at);
        """)
        
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Dead letter queue tables initialized")
    except Exception as e:
        logger.error(f"Failed to initialize DLQ tables: {e}")
        raise

def validate_data(data: Dict[str, Any], schema_type: str = "sales") -> Dict[str, Any]:
    """Validate data against schema and business rules"""
    validation_result = {
        "is_valid": True,
        "errors": [],
        "warnings": []
    }
    
    try:
        # JSON Schema validation
        if schema_type == "sales":
            jsonschema.validate(data, SALES_SCHEMA)
            
            # Pydantic validation for additional business rules
            sale_data = SaleData(**data)
            sale_data.validate_total_price()
            
        validation_total.labels(status='valid', schema_type=schema_type).inc()
        
    except jsonschema.ValidationError as e:
        validation_result["is_valid"] = False
        validation_result["errors"].append(f"Schema validation error: {e.message}")
        validation_errors.labels(error_type='schema_validation').inc()
        validation_total.labels(status='invalid', schema_type=schema_type).inc()
        
    except ValidationError as e:
        validation_result["is_valid"] = False
        validation_result["errors"].append(f"Data validation error: {e}")
        validation_errors.labels(error_type='data_validation').inc()
        validation_total.labels(status='invalid', schema_type=schema_type).inc()
        
    except ValueError as e:
        validation_result["is_valid"] = False
        validation_result["errors"].append(f"Business rule validation error: {e}")
        validation_errors.labels(error_type='business_rule').inc()
        validation_total.labels(status='invalid', schema_type=schema_type).inc()
        
    except Exception as e:
        validation_result["is_valid"] = False
        validation_result["errors"].append(f"Unexpected validation error: {e}")
        validation_errors.labels(error_type='unexpected').inc()
        validation_total.labels(status='invalid', schema_type=schema_type).inc()
    
    return validation_result

def send_to_dlq(data: Dict[str, Any], errors: List[str], schema_type: str):
    """Send failed validation to dead letter queue"""
    try:
        conn = get_conn(DLQ_DB)
        cur = conn.cursor()
        
        cur.execute("""
        INSERT INTO failed_validations (original_data, validation_errors, schema_type)
        VALUES (%s, %s, %s)
        """, [json.dumps(data), json.dumps(errors), schema_type])
        
        conn.commit()
        cur.close()
        conn.close()
        
        logger.info(f"Sent failed validation to DLQ: {len(errors)} errors")
        
    except Exception as e:
        logger.error(f"Failed to send to DLQ: {e}")

def process_holding_records():
    """Process records from holding database and validate them"""
    try:
        conn = get_conn(HOLDING_DB)
        cur = conn.cursor()
        
        # Get unprocessed records
        cur.execute("""
        SELECT id, data, received_at
        FROM holding_ingest
        WHERE processed = FALSE
        ORDER BY received_at
        LIMIT 100
        """)
        
        records = cur.fetchall()
        
        if not records:
            logger.info("No unprocessed records to validate")
            return
        
        logger.info(f"Validating {len(records)} records...")
        
        valid_count = 0
        invalid_count = 0
        
        for record_id, data_json, received_at in records:
            try:
                # Handle both JSON string and already-parsed dict from JSONB
                if isinstance(data_json, str):
                    data = json.loads(data_json)
                else:
                    data = data_json
                
                with validation_duration.time():
                    validation_result = validate_data(data, "sales")
                
                if validation_result["is_valid"]:
                    # Mark as processed
                    cur.execute("""
                    UPDATE holding_ingest 
                    SET processed = TRUE 
                    WHERE id = %s
                    """, [record_id])
                    valid_count += 1
                    logger.info(f"Record {record_id} validated successfully")
                else:
                    # Send to DLQ
                    send_to_dlq(data, validation_result["errors"], "sales")
                    invalid_count += 1
                    logger.warning(f"Record {record_id} failed validation: {validation_result['errors']}")
                
            except Exception as e:
                logger.error(f"Error processing record {record_id}: {e}")
                invalid_count += 1
        
        conn.commit()
        cur.close()
        conn.close()
        
        logger.info(f"Validation completed: {valid_count} valid, {invalid_count} invalid")
        
        # Update data quality score
        total_records = valid_count + invalid_count
        if total_records > 0:
            quality_score = (valid_count / total_records) * 100
            data_quality_score.set(quality_score)
        
    except Exception as e:
        logger.error(f"Error processing holding records: {e}")

def update_dlq_metrics():
    """Update dead letter queue size metric"""
    try:
        conn = get_conn(DLQ_DB)
        cur = conn.cursor()
        
        cur.execute("SELECT COUNT(*) FROM failed_validations")
        count = cur.fetchone()[0]
        dlq_size.set(count)
        
        cur.close()
        conn.close()
        
    except Exception as e:
        logger.error(f"Error updating DLQ metrics: {e}")

@app.route("/health")
def health():
    """Health check endpoint"""
    try:
        # Check holding DB
        holding_conn = get_conn(HOLDING_DB)
        holding_conn.close()
        
        # Check DLQ DB
        dlq_conn = get_conn(DLQ_DB)
        dlq_conn.close()
        
        return jsonify({"status": "healthy", "service": "data-validator"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route("/validate", methods=["POST"])
def validate_endpoint():
    """Validate data via API endpoint"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        schema_type = request.args.get("schema_type", "sales")
        
        with validation_duration.time():
            result = validate_data(data, schema_type)
        
        return jsonify(result), 200 if result["is_valid"] else 422
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/dlq/stats")
def dlq_stats():
    """Get dead letter queue statistics"""
    try:
        conn = get_conn(DLQ_DB)
        cur = conn.cursor()
        
        cur.execute("""
        SELECT 
            schema_type,
            COUNT(*) as count,
            MIN(failed_at) as oldest_failure,
            MAX(failed_at) as newest_failure
        FROM failed_validations
        GROUP BY schema_type
        """)
        
        stats = []
        for row in cur.fetchall():
            stats.append({
                "schema_type": row[0],
                "count": row[1],
                "oldest_failure": row[2].isoformat() if row[2] else None,
                "newest_failure": row[3].isoformat() if row[3] else None
            })
        
        cur.close()
        conn.close()
        
        return jsonify({"dlq_stats": stats}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/")
def index():
    """Service information"""
    return jsonify({
        "service": "data-validator",
        "status": "running",
        "endpoints": {
            "/health": "Health check",
            "/metrics": "Prometheus metrics",
            "/validate": "Validate data (POST)",
            "/dlq/stats": "Dead letter queue statistics"
        }
    })

def run_validation_loop():
    """Run the validation loop in a separate thread"""
    validation_interval = int(os.getenv("VALIDATION_INTERVAL", 30))
    
    while True:
        try:
            process_holding_records()
            update_dlq_metrics()
            logger.info(f"Waiting {validation_interval} seconds before next validation...")
            time.sleep(validation_interval)
        except KeyboardInterrupt:
            logger.info("Data validator stopped by user")
            break
        except Exception as e:
            logger.error(f"Unexpected error in validation loop: {e}")
            time.sleep(validation_interval)

if __name__ == "__main__":
    logger.info("Starting data validator...")
    
    # Initialize DLQ tables
    init_dlq_tables()
    
    # Start validation loop in a separate thread
    import threading
    validation_thread = threading.Thread(target=run_validation_loop, daemon=True)
    validation_thread.start()
    
    # Start Flask app
    logger.info("Starting Flask web server...")
    environment = os.getenv("ENVIRONMENT", "development")
    
    if environment == "production":
        # Use Gunicorn for production
        import gunicorn.app.wsgiapp as wsgi
        import sys
        sys.argv = [
            "gunicorn",
            "--bind", "0.0.0.0:8080",
            "--workers", "4",
            "--worker-class", "sync",
            "--worker-connections", "1000",
            "--max-requests", "1000",
            "--max-requests-jitter", "100",
            "--timeout", "30",
            "--keep-alive", "2",
            "--preload",
            "--access-logfile", "-",
            "--error-logfile", "-",
            "--log-level", "info",
            "data_validator:app"
        ]
        wsgi.run()
    else:
        # Use Flask dev server for development
        app.run(host='0.0.0.0', port=8080, debug=False)
