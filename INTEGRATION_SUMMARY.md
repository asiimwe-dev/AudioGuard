# AudioGuard - Integration Summary

## ✅ Status: READY FOR INTEGRATION

Both frontend and backend are complete and ready to work together!

---

## 📦 What You Have

### Backend (FastAPI)
```
/backend/
├── app.py              (Main entry point)
├── api/
│   ├── server.py       (FastAPI endpoints)
│   └── models.py       (Request/Response models)
├── engine/             (Core watermarking logic)
├── requirements.txt    (Python dependencies)
└── PHASE_4_COMPLETE.md (Documentation)
```

**Start Command:**
```bash
cd /home/asiimwe/Projects/AudioGuard/backend
python app.py
```

### Frontend (Flutter)
```
/frontend/
├── lib/
│   ├── services/api_service.dart    (API communication)
│   ├── screens/                     (6 UI screens)
│   ├── providers/                   (State management)
│   └── models/watermark_model.dart
├── pubspec.yaml                     (Dependencies)
└── build/app/outputs/flutter-apk/   (Production APK)
```

**Start Command:**
```bash
cd /home/asiimwe/Projects/AudioGuard/frontend
flutter run
```

---

## 🎯 Integration Points

### 1. API Configuration
**File**: `frontend/lib/utils/constants.dart`

Current setting:
```dart
static const String defaultApiBaseUrl = 'https://api.audioguard.io';
```

Change to:
```dart
// Android Emulator
static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';

// Physical Device (use your PC's IP)
static const String defaultApiBaseUrl = 'http://192.168.1.100:8000';
```

### 2. API Service
**File**: `frontend/lib/services/api_service.dart`

Handles all HTTP communication with backend:
- `encode()` - Embed watermark
- `decode()` - Extract watermark  
- `verify()` - Verify message
- `analyze()` - Audio analysis

### 3. Backend Endpoints
**File**: `backend/api/server.py`

Provides REST API:
```
GET  /health                  - Health check
POST /api/v1/encode           - Embed watermark
POST /api/v1/decode           - Extract watermark
POST /api/v1/verify           - Verify watermark
POST /api/v1/analyze          - Analyze audio
```

---

## 🚀 Quick Start (3 Commands)

### Terminal 1: Start Backend
```bash
cd /home/asiimwe/Projects/AudioGuard/backend && python app.py
```

### Terminal 2: Verify Backend
```bash
curl http://localhost:8000/health
```

### Terminal 3: Start Frontend
```bash
cd /home/asiimwe/Projects/AudioGuard/frontend && flutter run
```

---

## 🔄 Data Flow

### Encoding Watermark
```
[User Action]
    ↓
[App: Select Audio]
    ↓
[App: Enter Message]
    ↓
[Frontend → Backend]
POST http://localhost:8000/api/v1/encode
{
  "audio_file": <binary>,
  "message": "my-watermark"
}
    ↓
[Backend Processing]
- Load audio file
- Apply STFT
- Embed watermark in frequency domain
- Save watermarked file
- Return confidence score
    ↓
[Backend → Frontend]
{
  "status": "success",
  "encoded_file": <binary>,
  "confidence": 0.95,
  "processing_time_ms": 2340
}
    ↓
[App Display Result] ✅
```

### Decoding Watermark
```
[User Action]
    ↓
[App: Select Watermarked Audio]
    ↓
[Frontend → Backend]
POST http://localhost:8000/api/v1/decode
{
  "audio_file": <binary>
}
    ↓
[Backend Processing]
- Load audio file
- Apply STFT
- Extract watermark bits
- Decode to message
- Calculate confidence
    ↓
[Backend → Frontend]
{
  "status": "success",
  "message": "my-watermark",
  "confidence": 0.92,
  "suggestions": [],
  "processing_time_ms": 1850
}
    ↓
[App Display Message] ✅
```

---

## 📱 Screens & Their Backend Calls

### Home Screen
- No backend calls (displays local stats)

### Encode Screen
- **Backend Call**: POST /api/v1/encode
- **Input**: Audio file + message
- **Output**: Watermarked audio + confidence

### Decode Screen
- **Backend Call**: POST /api/v1/decode
- **Input**: Audio file
- **Output**: Extracted message + confidence

### Verify Screen
- **Backend Call**: POST /api/v1/verify
- **Input**: Audio file + expected message
- **Output**: Match result + confidence

### Analyze Screen
- **Backend Call**: POST /api/v1/analyze
- **Input**: Audio file
- **Output**: Analysis results + watermark presence

### Settings Screen
- No backend calls (local configuration only)

---

## 🛠️ Configuration Options

### Backend Configuration

**Environment Variables** (optional):
```bash
export AUDIOGUARD_HOST=0.0.0.0
export AUDIOGUARD_PORT=8000
export AUDIOGUARD_WORKERS=4
```

**Command Line Options**:
```bash
python app.py --host 0.0.0.0 --port 8000 --workers 4
```

### Frontend Configuration

**API URL** (in constants.dart):
```dart
// Development (local)
static const String devApiBaseUrl = 'http://localhost:8000';

// Staging
static const String stagingApiBaseUrl = 'https://staging-api.audioguard.io';

// Production
static const String defaultApiBaseUrl = 'https://api.audioguard.io';
```

**Request Timeout** (in constants.dart):
```dart
static const Duration apiTimeout = Duration(seconds: 30);
static const Duration fileUploadTimeout = Duration(minutes: 5);
```

---

## 🧪 Testing the Integration

### Manual Testing (In App)

1. **Open Frontend App**
   - Should start successfully
   - Settings screen shows API URL

2. **Test Encode**
   - Select audio file
   - Enter watermark message
   - Click "Embed Watermark"
   - Should complete in 2-5 seconds
   - Confidence displayed

3. **Test Decode**
   - Select watermarked file
   - Click "Extract Watermark"
   - Should show extracted message
   - Confidence displayed

4. **Test Verify**
   - Select watermarked file
   - Enter expected message
   - Click "Verify"
   - Should show match result

### Testing with cURL (From Terminal)

```bash
# Health check
curl http://localhost:8000/health

# Encode (if you have test audio file)
curl -X POST http://localhost:8000/api/v1/encode \
  -F "audio_file=@test.wav" \
  -F "message=test-watermark"

# Decode
curl -X POST http://localhost:8000/api/v1/decode \
  -F "audio_file=@watermarked.wav"
```

---

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "API server is unreachable" | Start backend: `python app.py` |
| "Connection timeout" | Check backend logs, verify port 8000 |
| "Wrong IP on physical device" | Find your PC IP: `hostname -I` |
| "File not found" | Ensure audio file exists in storage |
| "Backend crashes" | Check Python dependencies: `pip install -r requirements.txt` |
| "Port 8000 already in use" | Kill process or use different port |

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  AudioGuard System                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Frontend (Flutter Mobile App)              │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │ • Home Screen         • Encode Screen               │  │
│  │ • Decode Screen       • Verify Screen               │  │
│  │ • Analyze Screen      • Settings Screen             │  │
│  │                                                      │  │
│  │ ┌────────────────────────────────────────────────┐  │  │
│  │ │ API Service (Dio HTTP Client)                  │  │  │
│  │ │ - baseUrl configuration                        │  │  │
│  │ │ - Request/Response handling                    │  │  │
│  │ │ - Error handling                               │  │  │
│  │ └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↕️                                  │
│              HTTP REST Communication                        │
│           (http://localhost:8000 or IP:8000)               │
│                          ↕️                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Backend (FastAPI Python Server)              │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │                                                      │  │
│  │ ┌────────────────────────────────────────────────┐  │  │
│  │ │ API Endpoints                                  │  │  │
│  │ │ - /health                                      │  │  │
│  │ │ - /api/v1/encode                              │  │  │
│  │ │ - /api/v1/decode                              │  │  │
│  │ │ - /api/v1/verify                              │  │  │
│  │ │ - /api/v1/analyze                             │  │  │
│  │ └────────────────────────────────────────────────┘  │  │
│  │                          ↓                           │  │
│  │ ┌────────────────────────────────────────────────┐  │  │
│  │ │ Audio Processing Engine                        │  │  │
│  │ │ - STFT (librosa)                               │  │  │
│  │ │ - Bit spreading                                │  │  │
│  │ │ - Magnitude modulation                         │  │  │
│  │ │ - Watermark embedding                          │  │  │
│  │ └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Integration Checklist

- [x] Backend FastAPI server implemented
- [x] Frontend Flutter app built
- [x] API endpoints defined in backend
- [x] API service implemented in frontend
- [x] Production APK created (73.6 MB)
- [x] Integration guide written
- [x] Configuration documented
- [x] Error handling implemented
- [ ] **TODO**: Update frontend constants.dart with local API URL
- [ ] **TODO**: Start backend server
- [ ] **TODO**: Start frontend app
- [ ] **TODO**: Test integration (encode/decode)
- [ ] **TODO**: Deploy to production

---

## 🎓 Next Steps

1. **Update Configuration**
   - Edit `frontend/lib/utils/constants.dart`
   - Set API URL to local backend

2. **Start Services**
   - Backend: `python app.py`
   - Frontend: `flutter run`

3. **Test Integration**
   - Use app to encode watermark
   - Verify backend is processing requests
   - Check output files

4. **Production Deployment**
   - Build production APK
   - Deploy backend to server
   - Update API URL in production build

---

## 📚 Documentation

- **Quick Start**: `START_INTEGRATION.md`
- **Full Integration Guide**: `FRONTEND_BACKEND_INTEGRATION.md`
- **Backend Documentation**: `backend/PHASE_4_COMPLETE.md`
- **Frontend Documentation**: `frontend/FLUTTER_PHASE5_COMPLETE.md`

---

**Status**: ✅ Ready to Integrate  
**Last Updated**: April 24, 2026  
**Version**: 1.0
