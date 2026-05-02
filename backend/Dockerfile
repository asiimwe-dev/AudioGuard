# AudioGuard Multi-Stage Docker Build
# Optimized for Render Free Tier with a focus on minimal image size and efficient caching.

# --- Stage 1: Builder ---
FROM python:3.11-slim as builder

# Set environment variables to ensure pip doesn't cache and venv is clean
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Install build dependencies for SFFT engine
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a virtual environment in /opt/venv
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies into the venv
COPY requirements.txt requirements-api.txt* ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    if [ -f requirements-api.txt ]; then pip install --no-cache-dir -r requirements-api.txt; fi

# --- Stage 2: Runtime ---
FROM python:3.11-slim

WORKDIR /app

# Install runtime-only audio libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire virtual environment from the builder
COPY --from=builder /opt/venv /opt/venv

# Set PATH to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PORT=10000

# Copy application code
COPY engine/ ./engine/
COPY api/ ./api/
COPY main.py app.py ./

# Create appuser and give them ownership of the app directory
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Health check (Render uses port 10000 by default for some free instances)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

EXPOSE ${PORT}

# Run API server - Using 1 worker for the Free Tier to save RAM
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "10000", "--workers", "1"]