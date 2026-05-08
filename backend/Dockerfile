# ─── AudioGuard Production Dockerfile ───────────────────────────────────────

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
LABEL version="2.0.0"

# Runtime system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r audioguard \
    && useradd -r -g audioguard -s /bin/false audioguard

COPY --from=builder /install /usr/local

WORKDIR /app
COPY . .

# ── CRITICAL FIX: Permissions ──
# We create the directory and set permissions while we are still ROOT.
RUN mkdir -p /tmp/audioguard_storage && \
    chown -R audioguard:audioguard /app /tmp/audioguard_storage

# Now safe to switch to non-root user
USER audioguard

# ── Environment Configuration ──
# Render defaults to 10000, but this setup adapts to whatever the host provides.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    AUDIOGUARD_STORAGE_DIR=/tmp/audioguard_storage \
    PORT=10000

# EXPOSE is primarily for documentation
EXPOSE 10000

# ── Healthcheck ──
# Uses the dynamic port variable to check if the app is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; import os; port = os.getenv('PORT', '10000'); urllib.request.urlopen(f'http://localhost:{port}/health')"

# ── Execution ──
# We use 'sh -c' so that the $PORT variable is correctly expanded by the shell.
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT} --workers 2 --log-level info --access-log"]