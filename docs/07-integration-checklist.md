# Integration Checklist

This checklist provides a step-by-step guide to verify the complete integration between the AudioGuard mobile application and the backend server.

## Table of Contents
1. [Preparation](#preparation)
2. [Service Verification](#service-verification)
3. [End-to-End Testing](#end-to-end-testing)
4. [Troubleshooting](#troubleshooting)
5. [Quick Integration Commands](#quick-integration-commands)

## Preparation

### Backend Setup
*   [ ] Python 3.11+ installed.
*   [ ] Dependencies installed: `pip install -r requirements.txt -r requirements-api.txt`.
*   [ ] Storage directory created: `/tmp/audioguard_storage`.
*   [ ] Backend server started: `python app.py`.
*   [ ] Health check responding: `curl http://localhost:8000/health`.

### Frontend Setup
*   [ ] Flutter 3.41+ installed.
*   [ ] Dependencies installed: `flutter pub get`.
*   [ ] API URL configured in `lib/utils/constants.dart`:
    *   **Emulator**: `http://10.0.2.2:8000`
    *   **Physical Device**: `http://<your-ip>:8000`
*   [ ] App running on emulator or physical device.

## Service Verification

### Health Check
1.  Open the mobile app and navigate to **Settings**.
2.  Observe the "API Status" indicator.
3.  **Expected Result**: Status should show "Connected" or "Healthy".

### Connectivity Test
1.  From a terminal, run: `curl http://<backend-ip>:8000/health`.
2.  **Expected Result**: `{"status": "healthy", ...}`.
3.  If this fails, verify that the mobile device and backend are on the same network and port 8000 is open.

## End-to-End Testing

### Test 1: Watermark Encoding
1.  In the app, go to the **Encode** screen.
2.  Pick a short WAV audio file.
3.  Enter a test message (e.g., "INTEGRATION_001").
4.  Tap **Embed Watermark**.
5.  **Expected Result**: Processing takes < 5 seconds, a success message is shown, and a `file_id` is generated.

### Test 2: Watermark Verification
1.  Go to the **Verify** screen.
2.  Select the watermarked file from Test 1.
3.  Tap **Verify**.
4.  **Expected Result**: "Watermark Detected" with confidence > 0.85.

### Test 3: Watermark Decoding
1.  Go to the **Decode** screen.
2.  Select the watermarked file.
3.  Tap **Extract Message**.
4.  **Expected Result**: The message "INTEGRATION_001" is successfully extracted.

## Troubleshooting

### "Connection Refused"
*   Ensure the backend host is set to `0.0.0.0` in `app.py`.
*   Check that the backend machine's firewall allows incoming traffic on port 8000.
*   Verify the API URL in `lib/utils/constants.dart`.

### "Extraction Failed"
*   Ensure the audio file has not been transcoded or heavily compressed.
*   Try increasing the `amplitude_factor` in settings if detection confidence is consistently low.

## Quick Integration Commands

### Backend Startup
```bash
cd backend
python app.py
```

### Backend Health Check
```bash
curl http://localhost:8000/health
```

### Manual Encode Test
```bash
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@sample.wav" \
  -F "message=TEST_SIGNAL"
```

---
[Return to Documentation Index](README.md)
