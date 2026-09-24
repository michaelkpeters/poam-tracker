FROM python:3.11-slim

WORKDIR /app

# Install build dependencies (for greenlet if needed), then clean up
RUN apt-get update && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create data directory for SQLite DB and uploaded evidence files
RUN mkdir -p /app/data/uploads

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Initialize DB on first start, then serve with Waitress
CMD ["python", "-c", "from init_db import init_database; init_database(); from waitress import serve; from app import app; serve(app, host='0.0.0.0', port=5000, threads=4)"]
