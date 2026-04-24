# AudioGuard - Frontend & Backend Integration Guide

## 🎯 Current Status

**Backend**: FastAPI server running on port 8000  
**Frontend**: Flutter mobile app built and ready  
**Goal**: Connect them for full functionality

---

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   AudioGuard Project                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  /backend/              /frontend/                           │
│  ├── app.py             ├── lib/                             │
│  ├── api/               │   ├── services/                    │
│  │   ├── server.py      │   │   └── api_service.dart        │
│  │   └── models.py      │   ├── providers/                  │
│  ├── engine/            │   ├── screens/                    │
│  ├── requirements.txt    │   └── models/                    │
│  └── main.py            ├── pubspec.yaml                    │
│                         └── build/                          │
│                             └── app-release.apk             │
│                                                               │
│  Endpoints: /api/v1/encode, /api/v1/decode, ...             │
│  Port: 8000                                                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                              ⬆️⬇️
                     HTTP REST Communication
                         (http://localhost:8000)
```

---

## 🚀 Quick Start - Integration Steps

### Step 1: Start the Backend Server

Open **Terminal 1** and run:

```bash
cd /home/asiimwe/Projects/AudioGuard/backend

# Install dependencies (first time only)
pip install -r requirements.txt

# Start the server
python app.py
# or with uvicorn:
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

### Step 2: Check Backend Health

In **Terminal 2**, verify the server is running:

```bash
curl http://localhost:8000/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "service": "AudioGuard API",
  "version": "1.0.0"
}
```

### Step 3: Configure Frontend to Use Local Backend

Update the constants in **`frontend/lib/utils/constants.dart`**:

```dart
// Change this line:
static const String defaultApiBaseUrl = 'https://api.audioguard.io';

// To this:
static const String defaultApiBaseUrl = 'http://192.168.1.X:8000';
// OR for Android emulator:
static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';
```

**Important Notes:**
- **Physical device**: Use your computer's local IP (e.g., `192.168.1.100`)
- **Android emulator**: Use `10.0.2.2` (special alias for host machine)
- **iOS simulator**: Use `localhost:8000` or `127.0.0.1:8000`

### Step 4: Start the Frontend App

In **Terminal 3**, run:

```bash
cd /home/asiimwe/Projects/AudioGuard/frontend

# Make sure emulator/device is connected
flutter devices

# Run the app
flutter run
```

### Step 5: Test the Integration

In the app:
1. Navigate to **Settings** screen
2. Change **API URL** to your local backend (if not already done)
3. Go to **Encode** screen
4. Select an audio file
5. Enter a watermark message
6. Click **Embed Watermark**
7. Check terminal for success/error messages

---

## 📡 API Endpoints

### Backend Endpoints (FastAPI)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/v1/encode` | POST | Embed watermark in audio |
| `/api/v1/decode` | POST | Extract watermark from audio |
| `/api/v1/verify` | POST | Verify watermark authenticity |
| `/api/v1/analyze` | POST | Analyze audio for watermarks |

### Frontend API Client

Located in: `frontend/lib/services/api_service.dart`

```dart
// Initialize with local backend
final apiService = ApiService(
  baseUrl: 'http://localhost:8000'
);

// Encode watermark
final result = await apiService.encode(
  audioFilePath: '/path/to/audio.wav',
  message: 'My watermark',
);

// Decode watermark
final result = await apiService.decode(
  audioFilePath: '/path/to/audio.wav',
);

// Verify watermark
final result = await apiService.verify(
  audioFilePath: '/path/to/audio.wav',
  expectedMessage: 'My watermark',
);

// Analyze audio
final result = await apiService.analyze(
  audioFilePath: '/path/to/audio.wav',
);
```

---

## 🔧 Configuration Files

### Backend Configuration

**File**: `backend/requirements.txt`
```
fastapi==0.104.0
uvicorn==0.24.0
numpy==1.24.3
librosa==0.10.0
scipy==1.11.4
soundfile==0.12.1
torch==2.0.0
```

**File**: `backend/app.py`
```python
from api import create_app

app = create_app(debug=False)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",    # Listen on all interfaces
        port=8000,         # Port number
        workers=4,         # Multiple workers
        reload=False,      # Disable auto-reload in production
    )
```

### Frontend Configuration

**File**: `frontend/lib/utils/constants.dart`
```dart
class AppConstants {
  // Development (local backend)
  static const String devApiBaseUrl = 'http://localhost:8000';
  
  // Current default (production)
  static const String defaultApiBaseUrl = 'https://api.audioguard.io';
  
  // Endpoints
  static const String encodeEndpoint = '/api/v1/encode';
  static const String decodeEndpoint = '/api/v1/decode';
  static const String verifyEndpoint = '/api/v1/verify';
  static const String analyzeEndpoint = '/api/v1/analyze';
}
```

---

## 📊 Data Flow

### Encoding Watermark Flow

```
User Action (Frontend)
        ⬇️
Select Audio File
        ⬇️
Enter Watermark Message
        ⬇️
Click "Embed Watermark"
        ⬇️
APIService.encode(audioFilePath, message)
        ⬇️
HTTP POST to http://localhost:8000/api/v1/encode
        ⬇️
Backend: Load audio → Apply STFT → Embed watermark → Save file
        ⬇️
HTTP Response: {encoded_file, confidence, processing_time}
        ⬇️
Frontend: Display result, save to local storage
        ⬇️
User sees confirmation ✅
```

### Decoding Watermark Flow

```
User Action (Frontend)
        ⬇️
Select Encoded Audio File
        ⬇️
Click "Extract Watermark"
        ⬇️
APIService.decode(audioFilePath)
        ⬇️
HTTP POST to http://localhost:8000/api/v1/decode
        ⬇️
Backend: Load audio → Apply STFT → Extract watermark
        ⬇️
HTTP Response: {message, confidence, processing_time}
        ⬇️
Frontend: Display extracted message
        ⬇️
User sees extracted watermark ✅
```

---

## 🧪 Testing Integration

### 1. Using cURL (Terminal)

```bash
# Test encode endpoint
curl -X POST http://localhost:8000/api/v1/encode \
  -H "Content-Type: multipart/form-data" \
  -F "audio_file=@/path/to/audio.wav" \
  -F "message=test"

# Test health check
curl http://localhost:8000/health

# Test decode endpoint
curl -X POST http://localhost:8000/api/v1/decode \
  -H "Content-Type: multipart/form-data" \
  -F "audio_file=@/path/to/watermarked.wav"
```

### 2. Using Frontend App

1. Open app in emulator/device
2. Go to **Settings** tab
3. Set API URL to `http://10.0.2.2:8000` (emulator) or `http://[your-ip]:8000` (device)
4. Go to **Encode** tab
5. Select audio file and enter watermark
6. Monitor logs: `flutter logs`

### 3. Using Postman

1. Import backend API documentation
2. Set base URL to `http://localhost:8000`
3. Create requests for each endpoint
4. Test encode/decode/verify/analyze

---

## 🐛 Troubleshooting

### Issue: "API server is unreachable"

**Cause 1**: Backend not running
```bash
# Solution: Start backend
cd /home/asiimwe/Projects/AudioGuard/backend
python app.py
```

**Cause 2**: Wrong API URL in frontend
```dart
// Check frontend/lib/utils/constants.dart
// Change defaultApiBaseUrl to correct local IP
static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';
```

**Cause 3**: Firewall blocking port 8000
```bash
# Solution: Allow port through firewall
sudo firewall-cmd --add-port=8000/tcp --permanent
sudo firewall-cmd --reload
```

### Issue: "Connection timeout"

**Cause**: Backend is running but frontend can't reach it
```bash
# Test backend is responding
curl -v http://localhost:8000/health

# If on device, test from device
adb shell curl http://10.0.2.2:8000/health
```

### Issue: "File not found" when processing audio

**Solution**: Ensure audio file exists and is readable
```bash
# Check file permissions
ls -la /path/to/audio.wav

# Or use absolute path from app storage
/data/user/0/com.audioguard.mobile/files/audio.wav
```

### Issue: "CORS error" in frontend

**Solution**: Backend needs CORS headers
```python
# In backend/api/server.py, add CORS middleware:
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 📱 Network Configuration for Different Devices

### Android Emulator
```
Backend URL: http://10.0.2.2:8000
Why: 10.0.2.2 is special alias for host machine in Android emulator
```

### Physical Android Device
```
Backend URL: http://192.168.1.100:8000
Why: Use your computer's local network IP
How to find IP:
  - Linux/Mac: ifconfig | grep "inet " | grep -v 127
  - Windows: ipconfig | findstr IPv4
```

### iOS Simulator
```
Backend URL: http://localhost:8000
Why: Simulator runs on host machine directly
```

### iOS Physical Device
```
Backend URL: http://192.168.1.100:8000
Why: Same as Android physical device
```

---

## 🔐 Security Considerations

### Development

For development, you can use:
```dart
// Allow all origins (DEV ONLY)
static const String devApiBaseUrl = 'http://localhost:8000';
```

### Production

For production, implement:

1. **HTTPS/TLS**
```python
# Use SSL certificates
uvicorn app:app --ssl-keyfile key.pem --ssl-certfile cert.pem
```

2. **Authentication**
```dart
// Add API key/token to requests
dio.options.headers['Authorization'] = 'Bearer $token';
```

3. **Rate Limiting**
```python
from slowapi import Limiter
limiter = Limiter(key_func=get_remote_address)
app = Limiter(app)
```

---

## 📝 Environment Variables

Create `.env` file in backend root:

```env
# Backend Configuration
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
BACKEND_WORKERS=4
BACKEND_RELOAD=False

# API Configuration
API_VERSION=v1
API_TITLE=AudioGuard API

# Model Configuration
MODEL_PATH=./models/
MODEL_CACHE_SIZE=1000

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/api.log
```

---

## ✅ Integration Checklist

- [ ] Backend FastAPI server created (`backend/app.py`)
- [ ] Backend API endpoints implemented (`backend/api/server.py`)
- [ ] Frontend Flutter app created (`frontend/`)
- [ ] Frontend API service implemented (`frontend/lib/services/api_service.dart`)
- [ ] Constants configured for local development
- [ ] Backend running on http://localhost:8000
- [ ] Health check endpoint responding
- [ ] Frontend app connecting to backend
- [ ] Encoding/decoding working end-to-end
- [ ] Error handling and logging in place
- [ ] Tests passing for API communication
- [ ] Production deployment ready

---

## 🚀 Next Steps

1. **Start Backend**: `python app.py` in backend directory
2. **Start Frontend**: `flutter run` in frontend directory
3. **Test Integration**: Use app to encode/decode watermarks
4. **Monitor Logs**: Check terminal output for errors
5. **Deploy**: Follow production deployment guide

---

## 📚 Documentation References

- **Backend Docs**: `backend/PHASE_4_COMPLETE.md`
- **Frontend Docs**: `frontend/FLUTTER_PHASE5_COMPLETE.md`
- **API Documentation**: `backend/docs/`
- **Frontend Build Guide**: `frontend/BUILD_ARTIFACTS.md`

---

**Status**: ✅ Ready for Integration  
**Last Updated**: April 24, 2026  
**Version**: 1.0

