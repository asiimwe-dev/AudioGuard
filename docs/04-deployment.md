# Deployment Guide

This guide provides comprehensive instructions for deploying AudioGuard in various environments, from local development to production-ready cloud infrastructures.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [Docker Deployment (Recommended)](#docker-deployment-recommended)
4. [Manual Installation](#manual-installation)
5. [Production Considerations](#production-considerations)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Prerequisites

### Backend
*   Python 3.11+
*   FastAPI dependencies (see `requirements-api.txt`)
*   Optional: Docker and Docker Compose

### Frontend
*   Flutter 3.41+
*   Android SDK 31+ / iOS SDK 12+

## Environment Configuration

AudioGuard can be configured using environment variables to adapt to different environments without code changes.

### Backend Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `AUDIOGUARD_PORT` | Port for the FastAPI server | `8000` |
| `AUDIOGUARD_DEBUG` | Enable verbose logging and debug mode | `false` |
| `AUDIOGUARD_STORAGE_DIR` | Directory for processed audio storage | `/tmp/audioguard_storage` |
| `REDIS_URL` | URL for the Redis cache (optional) | `redis://localhost:6379/0` |

### Frontend Constants
Update `frontend/lib/utils/constants.dart` before building for production:
```dart
static const String defaultApiBaseUrl = 'https://api.audioguard.io';
```

## Docker Deployment (Recommended)

Docker provides the most reliable way to deploy the AudioGuard backend with all its dependencies isolated.

### Single Container (Backend Only)
```bash
cd backend
docker build -t audioguard-api:latest .
docker run -d -p 8000:8000 --name audioguard audioguard-api:latest
```

### Full Stack (Recommended for Production)
Using `docker-compose.yml` allows you to deploy the API alongside Nginx (for rate limiting) and Redis (for caching).
```bash
docker-compose up -d
```
This starts:
1.  **AudioGuard API**: The core FastAPI service.
2.  **Redis**: For high-speed metadata caching.
3.  **Nginx**: Acts as a reverse proxy with built-in rate limiting (10 req/s).

## Manual Installation

### Backend Setup
1.  **Clone & Navigate**:
    ```bash
    git clone https://github.com/asiimwe-dev/AudioGuard.git
    cd AudioGuard/backend
    ```
2.  **Virtual Environment**:
    ```bash
    python -m venv venv
    source venv/bin/activate
    ```
3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt -r requirements-api.txt
    ```
4.  **Production Server**:
    Use `uvicorn` with multiple workers for production:
    ```bash
    uvicorn api.server:app --host 0.0.0.0 --port 8000 --workers 4
    ```

### Frontend Build
1.  **Dependencies**: `flutter pub get`
2.  **Configuration**: Verify `lib/utils/constants.dart`.
3.  **Release Build**:
    *   **Android**: `flutter build apk --release`
    *   **iOS**: `flutter build ios --release` (Requires macOS)

## Production Considerations

### Security
*   **SSL/TLS**: Always serve the API over HTTPS. Use Nginx or a cloud load balancer for SSL termination.
*   **API Keys**: Implement the optional API key middleware for public-facing deployments.
*   **File Permissions**: Ensure the `AUDIOGUARD_STORAGE_DIR` has restricted read/write permissions for the application user only.

### Scalability
*   **Statelessness**: The API is stateless; you can scale horizontally by adding more containers behind a load balancer.
*   **Resource Limits**: In high-load environments, allocate at least 1GB of RAM and 2 CPU cores per worker.

### Storage
*   Processed files are stored temporarily. For high-availability, use a shared persistent volume or a cloud-native storage adapter.

## Monitoring and Maintenance

### Health Checks
Monitor the `/health` endpoint:
```bash
curl http://localhost:8000/health
```

### Cleanup Job
Processed files should be cleaned up regularly. A simple cron job can handle this:
```bash
# Delete files older than 6 hours
0 * * * * find /tmp/audioguard_storage -mmin +360 -type f -delete
```

### Logging
Logs are structured in JSON format for easy ingestion into monitoring stacks like ELK or CloudWatch.

---
[Return to Documentation Index](README.md)
