# AudioGuard Integration Checklist

## 🎯 Pre-Integration Setup

### Backend (FastAPI)
- [ ] Navigate to backend directory
  ```bash
  cd /home/asiimwe/Projects/AudioGuard/backend
  ```

- [ ] Install Python dependencies
  ```bash
  pip install -r requirements.txt
  pip install -r requirements-api.txt
  ```

- [ ] Verify backend files exist
  ```bash
  ls -la app.py api/server.py engine/
  ```

- [ ] Check Python version
  ```bash
  python --version  # Should be 3.11+
  ```

### Frontend (Flutter)
- [ ] Navigate to frontend directory
  ```bash
  cd /home/asiimwe/Projects/AudioGuard/frontend
  ```

- [ ] Verify Flutter installation
  ```bash
  flutter --version  # Should be 3.41.7+
  dart --version    # Should be 3.11.5+
  ```

- [ ] Check if APK already built
  ```bash
  ls -lh build/app/outputs/flutter-apk/app-release.apk
  ```

- [ ] Get dependencies
  ```bash
  flutter pub get
  ```

---

## 🔧 Configuration Steps

### Step 1: Update Frontend API Configuration

Edit: `/home/asiimwe/Projects/AudioGuard/frontend/lib/utils/constants.dart`

Find this section:
```dart
static const String defaultApiBaseUrl = 'https://api.audioguard.io';
static const String devApiBaseUrl = 'http://localhost:8000';
static const String stagingApiBaseUrl = 'https://staging-api.audioguard.io';
```

**For Local Development (Android Emulator):**
```dart
static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';
static const String devApiBaseUrl = 'http://10.0.2.2:8000';
```

**For Local Development (Physical Device):**
First, find your PC's IP:
```bash
hostname -I | awk '{print $1}'
```
Example output: `192.168.1.100`

Then update:
```dart
static const String defaultApiBaseUrl = 'http://192.168.1.100:8000';
static const String devApiBaseUrl = 'http://192.168.1.100:8000';
```

- [ ] Constants file updated
- [ ] IP address verified (if using physical device)

### Step 2: Verify Backend Configuration

Edit: `/home/asiimwe/Projects/AudioGuard/backend/app.py`

Current configuration should be:
```python
if __name__ == "__main__":
    uvicorn.run(
        "api.server:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
```

- [ ] Backend app.py is configured for port 8000
- [ ] Verify API endpoints exist in `api/server.py`

---

## 🚀 Start Services

### Terminal 1: Start Backend

```bash
cd /home/asiimwe/Projects/AudioGuard/backend
python app.py
```

Expected output:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Application startup complete
```

- [ ] Backend started successfully
- [ ] Logs show "Application startup complete"

### Terminal 2: Verify Backend Health

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{"status": "healthy", "service": "AudioGuard API"}
```

- [ ] Health check passed
- [ ] Backend is responding to requests

### Terminal 3: Start Frontend

**Option A: Android Emulator**
```bash
cd /home/asiimwe/Projects/AudioGuard/frontend
flutter run
```

**Option B: Physical Android Device**
```bash
# First verify device is connected
adb devices

# Then run
cd /home/asiimwe/Projects/AudioGuard/frontend
flutter run
```

Expected output:
```
Launching lib/main.dart on <device> in debug mode...
✓ Built successfully
✓ App started on device
```

- [ ] Frontend app started
- [ ] App loaded on device/emulator

---

## ✅ Integration Tests

### Test 1: Verify API Configuration
1. Open app → Go to Settings tab
2. Look for "API Base URL" field
3. Should show:
   - `http://10.0.2.2:8000` (emulator) OR
   - `http://192.168.1.100:8000` (physical device)

- [ ] API URL correctly displayed

### Test 2: Encode Watermark
1. Go to Encode tab
2. Tap "Pick File" and select an audio file
3. Enter watermark message (e.g., "test-watermark")
4. Tap "Embed Watermark"
5. Wait for processing (2-5 seconds)

Expected result:
- [ ] File processed without errors
- [ ] Success message displayed
- [ ] Confidence score shown
- [ ] Processing time displayed

**Backend should log:**
```
INFO:     POST /api/v1/encode HTTP/1.1" 200
INFO:     Processing audio: test_audio.wav
INFO:     Embedding watermark: test-watermark
INFO:     Processing complete in 2.34s
```

### Test 3: Decode Watermark
1. Go to Decode tab
2. Tap "Pick File" and select the watermarked file
3. Tap "Extract Watermark"
4. Wait for processing

Expected result:
- [ ] Watermark message extracted
- [ ] Message should match original
- [ ] Confidence score shown

**Example:**
- Original: "test-watermark"
- Extracted: "test-watermark"
- Confidence: 0.95+

### Test 4: Verify Watermark
1. Go to Verify tab
2. Tap "Pick File" and select a watermarked file
3. Enter the expected message
4. Tap "Verify"

Expected result:
- [ ] Match status shown (Matched/Not Matched)
- [ ] Confidence percentage displayed

### Test 5: Check Backend Logs
Monitor backend terminal for all API calls:

```
INFO:     POST /api/v1/encode - Received encoding request
INFO:     POST /api/v1/decode - Received decoding request
INFO:     POST /api/v1/verify - Received verification request
```

- [ ] All API calls logged
- [ ] No errors in backend logs

---

## 🐛 Troubleshooting

### Problem: "Connection refused" or "API server unreachable"

**Solution:**
```bash
# 1. Verify backend is running
ps aux | grep "python app.py"

# 2. Check if port 8000 is listening
netstat -tuln | grep 8000

# 3. Restart backend
cd /home/asiimwe/Projects/AudioGuard/backend
python app.py
```

- [ ] Backend restarted and running

### Problem: Wrong API URL on device

**Solution:**
1. Run on terminal: `hostname -I`
2. Update `constants.dart` with correct IP
3. Rebuild Flutter app: `flutter clean && flutter run`

- [ ] IP address updated and app rebuilt

### Problem: "Permission denied" for audio file

**Solution:**
1. On device, grant app permissions when prompted
2. Select audio file from internal storage or Documents
3. Retry operation

- [ ] Permissions granted

### Problem: Backend crashes during encoding

**Solution:**
1. Check Python dependencies:
   ```bash
   pip install -r requirements.txt -r requirements-api.txt
   ```
2. Check backend logs for specific error
3. Verify audio file format (should be .wav or .mp3)

- [ ] Dependencies installed
- [ ] Audio file in correct format

---

## 📊 Integration Status Dashboard

| Component | Status | Location |
|-----------|--------|----------|
| Backend Code | ✅ Ready | `backend/` |
| Backend API | ✅ Configured | `backend/api/server.py` |
| Frontend Code | ✅ Ready | `frontend/` |
| Frontend API Service | ✅ Implemented | `frontend/lib/services/api_service.dart` |
| Frontend Constants | ⚠️ **Needs Update** | `frontend/lib/utils/constants.dart` |
| Production APK | ✅ Built | `frontend/build/app/outputs/flutter-apk/app-release.apk` |
| Documentation | ✅ Complete | `*.md` files in root |

---

## ✨ Success Criteria

All items must be ✅:

- [ ] Backend running on port 8000
- [ ] Frontend constants.dart updated with correct API URL
- [ ] Flutter app launches successfully
- [ ] API health check passes
- [ ] Encode operation completes with watermark
- [ ] Decode operation extracts watermark correctly
- [ ] Verify operation validates watermark
- [ ] Backend logs show all API calls
- [ ] No errors in frontend or backend logs
- [ ] Processing times acceptable (2-5 seconds per operation)

---

## 📞 Quick Reference

### Backend Commands
```bash
# Start backend
cd /home/asiimwe/Projects/AudioGuard/backend && python app.py

# Health check
curl http://localhost:8000/health

# Test encode
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@test.wav" \
  -F "message=test-watermark"
```

### Frontend Commands
```bash
# Navigate to frontend
cd /home/asiimwe/Projects/AudioGuard/frontend

# Get dependencies
flutter pub get

# Run on emulator
flutter run

# Run on device
adb devices  # Verify device connected
flutter run

# Build release APK
flutter build apk --release
```

### Useful Diagnostics
```bash
# Check if ports are in use
netstat -tuln | grep 8000

# Find your IP address
hostname -I

# Check running Python processes
ps aux | grep python

# Android device info
adb devices
adb shell getprop ro.build.version.release
```

---

**Last Updated**: April 24, 2026  
**Version**: 1.0  
**Status**: Ready for Integration ✅
