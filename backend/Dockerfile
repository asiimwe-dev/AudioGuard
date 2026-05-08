# ─── AudioGuard Production Dockerfile ───────────────────────────────────────
# Multi-stage build: builder installs deps, runtime is lean.
# Includes FFmpeg for pydub/librosa format support.

# ── Stage 1: builder ─────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# System deps for audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

LABEL maintainer="AudioGuard <hi@audioguard.io>"
LABEL description="AudioGuard audio watermarking API"
LABEL version="2.0.0"

# Runtime system deps (FFmpeg + libsndfile)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r audioguard \
    && useradd -r -g audioguard -s /bin/false audioguard

COPY --from=builder /install /usr/local

WORKDIR /app
COPY . .

# Non-root user for security
RUN chown -R audioguard:audioguard /app
USER audioguard

# Storage + temp directories
RUN mkdir -p /tmp/audioguard_storage

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    AUDIOGUARD_STORAGE_DIR=/tmp/audioguard_storage \
    PORT=8000

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "app:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--log-level", "info", \
     "--access-log"]
