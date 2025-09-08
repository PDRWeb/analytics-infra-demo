import os
import time
import requests
import psycopg2
from flask import Flask, jsonify
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Prometheus metrics
health_check_total = Counter('health_check_total', 'Total health checks', ['service', 'status'])
service_status = Gauge('service_status', 'Service status (1=up, 0=down)', ['service'])
database_connections = Gauge('database_connections', 'Number of database connections', ['database'])
sync_queue_size = Gauge('sync_queue_size', 'Number of records waiting to sync')

# Configuration
SERVICES = {
    'api_receiver': os.getenv('API_RECEIVER_URL', 'http://api_receiver:8080'),
    'metabase': os.getenv('METABASE_URL', 'http://metabase:3000'),
    'prometheus': os.getenv('PROMETHEUS_URL', 'http://prometheus:9090')
}

DB_CONFIG = {
    'holding': {
        'host': 'holding_db',
        'port': 5432,
        'user': os.getenv('HOLDING_DB_USER', 'postgres'),
        'password': os.getenv('HOLDING_DB_PASS', 'password'),
        'dbname': os.getenv('HOLDING_DB_NAME', 'holding_db')
    },
    'main': {
        'host': 'postgres_main',
        'port': 5432,
        'user': os.getenv('MAIN_DB_USER', 'postgres'),
        'password': os.getenv('MAIN_DB_PASS', 'password'),
        'dbname': os.getenv('MAIN_DB_NAME', 'main_db')
    }
}

def check_service_health(service_name, url):
    """Check if a service is healthy"""
    try:
        if service_name == 'api_receiver':
            response = requests.get(f"{url}/health", timeout=5)
        elif service_name == 'metabase':
            response = requests.get(f"{url}/api/health", timeout=5)
        elif service_name == 'prometheus':
            response = requests.get(f"{url}/-/healthy", timeout=5)
        else:
            response = requests.get(url, timeout=5)
        
        is_healthy = response.status_code == 200
        status = 'up' if is_healthy else 'down'
        health_check_total.labels(service=service_name, status=status).inc()
        service_status.labels(service=service_name).set(1 if is_healthy else 0)
        return is_healthy, response.status_code
    except Exception as e:
        health_check_total.labels(service=service_name, status='down').inc()
        service_status.labels(service=service_name).set(0)
        return False, str(e)

def check_database_health(db_name, config):
    """Check database connectivity and get connection count"""
    try:
        conn = psycopg2.connect(**config)
        cur = conn.cursor()
        
        # Get connection count
        cur.execute("SELECT count(*) FROM pg_stat_activity WHERE datname = %s", (config['dbname'],))
        connection_count = cur.fetchone()[0]
        database_connections.labels(database=db_name).set(connection_count)
        
        cur.close()
        conn.close()
        return True, connection_count
    except Exception as e:
        database_connections.labels(database=db_name).set(0)
        return False, str(e)

def check_sync_queue():
    """Check how many records are waiting to be synced"""
    try:
        config = DB_CONFIG['holding']
        conn = psycopg2.connect(**config)
        cur = conn.cursor()
        
        cur.execute("""
            SELECT COUNT(*) 
            FROM holding_ingest h
            LEFT JOIN synced_records s ON h.id = s.holding_id
            WHERE s.holding_id IS NULL
        """)
        queue_size = cur.fetchone()[0]
        sync_queue_size.set(queue_size)
        
        cur.close()
        conn.close()
        return True, queue_size
    except Exception as e:
        sync_queue_size.set(0)
        return False, str(e)

@app.route('/health')
def health():
    """Health check endpoint"""
    results = {}
    overall_healthy = True
    
    # Check services
    for service_name, url in SERVICES.items():
        is_healthy, status = check_service_health(service_name, url)
        results[service_name] = {
            'status': 'healthy' if is_healthy else 'unhealthy',
            'details': status
        }
        if not is_healthy:
            overall_healthy = False
    
    # Check databases
    for db_name, config in DB_CONFIG.items():
        is_healthy, details = check_database_health(db_name, config)
        results[f'database_{db_name}'] = {
            'status': 'healthy' if is_healthy else 'unhealthy',
            'details': details
        }
        if not is_healthy:
            overall_healthy = False
    
    # Check sync queue
    is_healthy, queue_size = check_sync_queue()
    results['sync_queue'] = {
        'status': 'healthy' if is_healthy else 'unhealthy',
        'queue_size': queue_size
    }
    
    return jsonify({
        'status': 'healthy' if overall_healthy else 'unhealthy',
        'timestamp': time.time(),
        'services': results
    }), 200 if overall_healthy else 503

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/')
def index():
    """Simple status page"""
    return jsonify({
        'service': 'health-monitor',
        'status': 'running',
        'endpoints': {
            '/health': 'Health check for all services',
            '/metrics': 'Prometheus metrics'
        }
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
