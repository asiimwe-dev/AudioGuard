# Quick Start Guide

This guide will help you get AudioGuard up and running in a local development environment.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Backend Setup](#backend-setup)
3. [Frontend Setup](#frontend-setup)
4. [Verification](#verification)

## Prerequisites
*   Python 3.11+
*   Flutter 3.0+
*   Android/iOS SDK (for mobile targets)
*   Git

## Backend Setup

1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  Start the FastAPI server:
    ```bash
    python app.py
    ```
    The server will run on `http://localhost:8000`.

4.  Verify the backend is healthy:
    ```bash
    curl http://localhost:8000/health
    ```

## Frontend Setup

1.  Navigate to the frontend directory:
    ```bash
    cd frontend
    ```
2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```
3.  Configure the API endpoint in `lib/utils/constants.dart`:
    *   **Android Emulator**: Use `http://10.0.2.2:8000`
    *   **iOS Simulator/Local**: Use `http://localhost:8000`
    *   **Physical Device**: Use your machine's local IP (e.g., `http://192.168.1.100:8000`)

4.  Run the application:
    ```bash
    flutter run
    ```

## Verification

### Automated Tests
Run the backend test suite to ensure everything is configured correctly:
```bash
cd backend
python -m pytest tests/ -v
```

### Manual API Test
Embed a watermark using `curl`:
```bash
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@sample.wav" \
  -F "message=TEST_MESSAGE"
```

---
[Return to Documentation Index](README.md)
