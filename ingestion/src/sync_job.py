import os
import psycopg2
import time
import json
import logging
from datetime import datetime
from prometheus_client import Counter, Histogram, Gauge, start_http_server

HOLDING_DB = {
    "dbname": os.getenv("HOLDING_DB_NAME"),
    "user": os.getenv("HOLDING_DB_USER"),
    "password": os.getenv("HOLDING_DB_PASS"),
    "host": os.getenv("HOLDING_DB_HOST"),
    "port": os.getenv("HOLDING_DB_PORT", 5432),
}

MAIN_DB = {
    "dbname": os.getenv("MAIN_DB_NAME"),
    "user": os.getenv("MAIN_DB_USER"),
    "password": os.getenv("MAIN_DB_PASS"),
    "host": os.getenv("MAIN_DB_HOST"),
    "port": os.getenv("MAIN_DB_PORT", 5432),
}

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Prometheus metrics
sync_records_total = Counter('sync_records_total', 'Total records synced', ['status'])
sync_duration = Histogram('sync_duration_seconds', 'Time spent syncing records')
sync_errors_total = Counter('sync_errors_total', 'Total sync errors', ['error_type'])
sync_queue_size = Gauge('sync_queue_size', 'Number of records waiting to sync')

def get_conn(cfg):
    try:
        conn = psycopg2.connect(**cfg)
        logger.info(f"Connected to database: {cfg['dbname']}")
        return conn
    except psycopg2.Error as e:
        logger.error(f"Failed to connect to database {cfg['dbname']}: {e}")
        raise

def migrate_holding_table():
    """Migrate existing holding_ingest table to add missing columns"""
    try:
        h = get_conn(HOLDING_DB)
        hc = h.cursor()
        
        # Check if processed column exists
        hc.execute("""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'holding_ingest' AND column_name = 'processed'
        """)
        
        if not hc.fetchone():
            logger.info("Adding missing columns to holding_ingest table...")
            hc.execute("ALTER TABLE holding_ingest ADD COLUMN processed BOOLEAN DEFAULT FALSE")
            hc.execute("ALTER TABLE holding_ingest ADD COLUMN created_at TIMESTAMP DEFAULT NOW()")
            h.commit()
            logger.info("Added missing columns to holding_ingest")
        
        hc.close()
        h.close()
    except Exception as e:
        logger.error(f"Failed to migrate holding table: {e}")
        raise

def migrate_main_table():
    """Migrate existing main_ingest table to add missing columns"""
    try:
        m = get_conn(MAIN_DB)
        mc = m.cursor()
        
        # Check if synced_at column exists
        mc.execute("""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'main_ingest' AND column_name = 'synced_at'
        """)
        
        if not mc.fetchone():
            logger.info("Adding missing columns to main_ingest table...")
            mc.execute("ALTER TABLE main_ingest ADD COLUMN synced_at TIMESTAMP DEFAULT NOW()")
            mc.execute("ALTER TABLE main_ingest ADD COLUMN created_at TIMESTAMP DEFAULT NOW()")
            m.commit()
            logger.info(" Added missing columns to main_ingest")
        
        mc.close()
        m.close()
    except Exception as e:
        logger.error(f" Failed to migrate main table: {e}")
        raise

def ensure_tables():
    """Auto-create tables in both holding and main DBs if missing"""
    logger.info(" Ensuring tables exist...")
    
    # holding db
    try:
        h = get_conn(HOLDING_DB)
        hc = h.cursor()
        hc.execute("""
        CREATE TABLE IF NOT EXISTS holding_ingest (
            id SERIAL PRIMARY KEY,
            data JSONB NOT NULL,
            received_at TIMESTAMP NOT NULL DEFAULT NOW(),
            processed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        hc.execute("""
        CREATE TABLE IF NOT EXISTS synced_records (
            id SERIAL PRIMARY KEY,
            holding_id INT NOT NULL,
            synced_at TIMESTAMP NOT NULL
        );
        """)
        h.commit()
        hc.close()
        h.close()
        logger.info(" Holding DB tables ensured")
        
        # Migrate existing table if needed (add missing columns)
        migrate_holding_table()
        
        # Now create indexes after ensuring columns exist
        h = get_conn(HOLDING_DB)
        hc = h.cursor()
        hc.execute("""
        CREATE INDEX IF NOT EXISTS idx_holding_processed ON holding_ingest(processed);
        """)
        hc.execute("""
        CREATE INDEX IF NOT EXISTS idx_holding_received_at ON holding_ingest(received_at);
        """)
        h.commit()
        hc.close()
        h.close()
        
    except Exception as e:
        logger.error(f" Failed to ensure holding DB tables: {e}")
        raise

    # main db
    try:
        m = get_conn(MAIN_DB)
        mc = m.cursor()
        mc.execute("""
        CREATE TABLE IF NOT EXISTS main_ingest (
            id SERIAL PRIMARY KEY,
            data JSONB NOT NULL,
            received_at TIMESTAMP NOT NULL,
            synced_at TIMESTAMP DEFAULT NOW(),
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        m.commit()
        mc.close()
        m.close()
        logger.info(" Main DB tables ensured")
        
        # Migrate existing table if needed (add missing columns)
        migrate_main_table()
        
        # Now create indexes after ensuring columns exist
        m = get_conn(MAIN_DB)
        mc = m.cursor()
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_main_received_at ON main_ingest(received_at);
        """)
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_main_synced_at ON main_ingest(synced_at);
        """)
        # Create GIN index for JSONB queries
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_main_data_gin ON main_ingest USING GIN (data);
        """)
        m.commit()
        mc.close()
        m.close()
    except Exception as e:
        logger.error(f" Failed to ensure main DB tables: {e}")
        raise

def create_analytics_tables():
    """Create structured analytics tables for better performance"""
    try:
        m = get_conn(MAIN_DB)
        mc = m.cursor()
        
        # Create structured sales table
        mc.execute("""
        CREATE TABLE IF NOT EXISTS sales (
            id SERIAL PRIMARY KEY,
            sale_id VARCHAR(50) UNIQUE NOT NULL,
            sale_date TIMESTAMP NOT NULL,
            customer_id INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            item_name VARCHAR(255) NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price DECIMAL(10,2) NOT NULL,
            total_price DECIMAL(10,2) NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        
        # Create indexes for analytics queries
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);
        """)
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id);
        """)
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_sales_item ON sales(item_id);
        """)
        mc.execute("""
        CREATE INDEX IF NOT EXISTS idx_sales_total_price ON sales(total_price);
        """)
        
        m.commit()
        mc.close()
        m.close()
        logger.info(" Analytics tables created")
        
    except Exception as e:
        logger.error(f" Failed to create analytics tables: {e}")
        raise

def sync():
    with sync_duration.time():
        try:
            holding = get_conn(HOLDING_DB)
            main = get_conn(MAIN_DB)
            h_cur = holding.cursor()
            m_cur = main.cursor()

            h_cur.execute("""
                SELECT h.id, h.data, h.received_at
                FROM holding_ingest h
                LEFT JOIN synced_records s ON h.id = s.holding_id
                WHERE s.holding_id IS NULL
            """)
            rows = h_cur.fetchall()
            
            # Update queue size metric
            sync_queue_size.set(len(rows))
            
            if not rows:
                logger.info("  No new records to sync")
                return

            logger.info(f"🔄 Syncing {len(rows)} records...")
            synced_count = 0
            error_count = 0

            for row in rows:
                hid, data, ts = row
                try:
                    # Begin transaction for both databases
                    main.autocommit = False
                    holding.autocommit = False

                    m_cur.execute(
                        "INSERT INTO main_ingest (data, received_at) VALUES (%s, %s) RETURNING id",
                        [json.dumps(data), ts]
                    )
                    h_cur.execute(
                        "INSERT INTO synced_records (holding_id, synced_at) VALUES (%s, NOW())",
                        [hid]
                    )

                    main.commit()
                    holding.commit()
                    synced_count += 1
                    sync_records_total.labels(status='success').inc()
                    logger.info(f" Synced record {hid}")
                    
                except Exception as e:
                    main.rollback()
                    holding.rollback()
                    error_count += 1
                    sync_records_total.labels(status='error').inc()
                    sync_errors_total.labels(error_type='sync_error').inc()
                    logger.error(f" Error syncing row {hid}: {e}")
                finally:
                    main.autocommit = True
                    holding.autocommit = True

            logger.info(f" Sync completed: {synced_count}/{len(rows)} records synced")

        except Exception as e:
            sync_errors_total.labels(error_type='connection_error').inc()
            logger.error(f" Sync failed: {e}")
        finally:
            try:
                h_cur.close()
                m_cur.close()
                holding.close()
                main.close()
            except:
                pass

if __name__ == "__main__":
    logger.info(" Starting sync job...")
    
    # Start Prometheus metrics server
    start_http_server(8080)
    logger.info(" Prometheus metrics server started on port 8080")
    
    ensure_tables()  #  make sure tables exist before syncing
    create_analytics_tables()  #  create structured analytics tables
    
    while True:
        try:
            sync()
            logger.info(" Waiting 60 seconds before next sync...")
            time.sleep(60)
        except KeyboardInterrupt:
            logger.info(" Sync job stopped by user")
            break
        except Exception as e:
            logger.error(f" Unexpected error in sync loop: {e}")
            logger.info(" Waiting 60 seconds before retry...")
            time.sleep(60)
