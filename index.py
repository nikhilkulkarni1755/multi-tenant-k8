#!/usr/bin/env python3
"""
Tenant information service
Displays company name and industry information
Enhanced with Prometheus metrics
"""

import os
import time
from flask import Flask, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Get environment variables set by ConfigMap
COMPANY = os.getenv("COMPANY", "Unknown")
INDUSTRY = os.getenv("INDUSTRY", "Unknown")
TENANT_NAME = os.getenv("TENANT_NAME", COMPANY.lower())

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'tenant', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint', 'tenant'],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)

ACTIVE_REQUESTS = Gauge(
    'http_requests_active',
    'Active HTTP requests',
    ['tenant']
)

REQUEST_ERRORS = Counter(
    'http_request_errors_total',
    'Total HTTP request errors',
    ['method', 'endpoint', 'tenant', 'error_type']
)

APP_INFO = Gauge(
    'app_info',
    'Application information',
    ['company', 'industry', 'tenant']
)
APP_INFO.labels(company=COMPANY, industry=INDUSTRY, tenant=TENANT_NAME).set(1)


@app.before_request
def before_request():
    """Track active requests"""
    request.start_time = time.time()
    ACTIVE_REQUESTS.labels(tenant=TENANT_NAME).inc()


@app.after_request
def after_request(response):
    """Record metrics after request"""
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.path,
            tenant=TENANT_NAME
        ).observe(duration)

        ACTIVE_REQUESTS.labels(tenant=TENANT_NAME).dec()

    # Record request count
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        tenant=TENANT_NAME,
        status=response.status_code
    ).inc()

    return response


@app.errorhandler(Exception)
def handle_error(error):
    """Track errors"""
    REQUEST_ERRORS.labels(
        method=request.method,
        endpoint=request.path,
        tenant=TENANT_NAME,
        error_type=type(error).__name__
    ).inc()
    return str(error), 500


@app.route("/hello", methods=["GET"])
def hello():
    """Return hello world with company and industry"""
    return f"Hello World {COMPANY}, {INDUSTRY}\n"


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return "OK\n"


@app.route("/metrics", methods=["GET"])
def metrics():
    """Expose Prometheus metrics"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    print(f"Starting tenant app for {COMPANY} ({INDUSTRY})")
    print("Prometheus metrics available at http://localhost:5000/metrics")
    app.run(host="0.0.0.0", port=5000, debug=False)
