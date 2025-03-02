import os
import time
import random
from flask import Flask, jsonify
import redis
import mysql.connector
from mysql.connector import Error
import prometheus_client
from prometheus_client import Counter, Histogram, Gauge, generate_latest

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('app_request_count', 'Total app HTTP request count')
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Request latency in seconds')
REDIS_ERRORS = Counter('app_redis_errors', 'Redis connection errors')
MYSQL_ERRORS = Counter('app_mysql_errors', 'MySQL connection errors')
REDIS_LATENCY = Histogram('app_redis_latency_seconds', 'Redis operation latency in seconds')
MYSQL_LATENCY = Histogram('app_mysql_latency_seconds', 'MySQL operation latency in seconds')
REDIS_UP = Gauge('app_redis_up', 'Redis connection status (1=up, 0=down)')
MYSQL_UP = Gauge('app_mysql_up', 'MySQL connection status (1=up, 0=down)')

# Configuration from environment variables
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
# Handle Kubernetes service environment variables
redis_port_env = os.environ.get('REDIS_PORT', '6379')
if redis_port_env.startswith('tcp://'):
    # Extract port from tcp://ip:port format
    REDIS_PORT = int(redis_port_env.split(':')[-1])
else:
    REDIS_PORT = int(redis_port_env)

MYSQL_HOST = os.environ.get('MYSQL_HOST', 'localhost')
MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', 'password')
MYSQL_DATABASE = os.environ.get('MYSQL_DATABASE', 'demo')

# Initialize Redis client
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_timeout=5)

# Function to get MySQL connection
def get_mysql_connection():
    try:
        connection = mysql.connector.connect(
            host=MYSQL_HOST,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD,
            database=MYSQL_DATABASE,
            connection_timeout=5
        )
        return connection
    except Error as e:
        app.logger.error(f"Error connecting to MySQL: {e}")
        MYSQL_ERRORS.inc()
        MYSQL_UP.set(0)
        return None

# Initialize database if it doesn't exist
def init_db():
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS counters (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    value INT NOT NULL
                )
            ''')
            # Check if we need to insert initial data
            cursor.execute("SELECT COUNT(*) FROM counters WHERE name = 'visits'")
            count = cursor.fetchone()[0]
            if count == 0:
                cursor.execute("INSERT INTO counters (name, value) VALUES ('visits', 0)")
            connection.commit()
            MYSQL_UP.set(1)
        except Error as e:
            app.logger.error(f"Error initializing database: {e}")
            MYSQL_ERRORS.inc()
            MYSQL_UP.set(0)
        finally:
            if connection.is_connected():
                cursor.close()
                connection.close()

# Initialize database on startup
init_db()

@app.route('/')
@REQUEST_LATENCY.time()
def index():
    REQUEST_COUNT.inc()
    
    # Redis operation
    redis_status = "OK"
    redis_start = time.time()
    try:
        redis_client.incr('visits')
        visits_redis = int(redis_client.get('visits'))
        REDIS_UP.set(1)
    except Exception as e:
        app.logger.error(f"Redis error: {e}")
        visits_redis = -1
        redis_status = f"ERROR: {str(e)}"
        REDIS_ERRORS.inc()
        REDIS_UP.set(0)
    finally:
        redis_end = time.time()
        REDIS_LATENCY.observe(redis_end - redis_start)
    
    # MySQL operation
    mysql_status = "OK"
    mysql_start = time.time()
    visits_mysql = -1
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("UPDATE counters SET value = value + 1 WHERE name = 'visits'")
            connection.commit()
            cursor.execute("SELECT value FROM counters WHERE name = 'visits'")
            visits_mysql = cursor.fetchone()[0]
            MYSQL_UP.set(1)
        except Error as e:
            app.logger.error(f"MySQL error: {e}")
            mysql_status = f"ERROR: {str(e)}"
            MYSQL_ERRORS.inc()
            MYSQL_UP.set(0)
        finally:
            if connection.is_connected():
                cursor.close()
                connection.close()
            mysql_end = time.time()
            MYSQL_LATENCY.observe(mysql_end - mysql_start)
    else:
        mysql_status = "ERROR: Could not connect to MySQL"
    
    return jsonify({
        'message': 'Hello from Chaos Demo!',
        'redis_visits': visits_redis,
        'mysql_visits': visits_mysql,
        'redis_status': redis_status,
        'mysql_status': mysql_status
    })

@app.route('/health')
def health():
    redis_healthy = True
    mysql_healthy = True
    
    # Check Redis
    try:
        redis_client.ping()
    except:
        redis_healthy = False
    
    # Check MySQL
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchone()
        except:
            mysql_healthy = False
        finally:
            if connection.is_connected():
                cursor.close()
                connection.close()
    else:
        mysql_healthy = False
    
    status = 200 if redis_healthy and mysql_healthy else 503
    return jsonify({
        'status': 'healthy' if status == 200 else 'unhealthy',
        'redis': 'up' if redis_healthy else 'down',
        'mysql': 'up' if mysql_healthy else 'down'
    }), status

@app.route('/metrics')
def metrics():
    return generate_latest(prometheus_client.REGISTRY)

@app.route('/redis-test')
def redis_test():
    try:
        # Simulate a more complex Redis operation
        key = f"test-{random.randint(1, 1000)}"
        redis_client.set(key, "test-value")
        value = redis_client.get(key)
        redis_client.delete(key)
        return jsonify({'status': 'success', 'value': value.decode('utf-8')})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/mysql-test')
def mysql_test():
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT NOW()")
            result = cursor.fetchone()
            return jsonify({'status': 'success', 'time': str(result[0])})
        except Error as e:
            return jsonify({'status': 'error', 'message': str(e)}), 500
        finally:
            if connection.is_connected():
                cursor.close()
                connection.close()
    else:
        return jsonify({'status': 'error', 'message': 'Could not connect to MySQL'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080) 