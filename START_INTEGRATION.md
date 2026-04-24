# AudioGuard - Quick Integration Start

## 🚀 3-Step Quick Start

### Step 1: Start Backend (Terminal 1)
```bash
cd /home/asiimwe/Projects/AudioGuard/backend
python app.py
```
✅ Wait until you see: `Uvicorn running on http://0.0.0.0:8000`

### Step 2: Verify Backend (Terminal 2)
```bash
curl http://localhost:8000/health
```
✅ You should see:
```json
{"status": "healthy", "service": "AudioGuard API"}
```

### Step 3: Start Frontend (Terminal 3)

**Option A: Android Emulator**
```bash
cd /home/asiimwe/Projects/AudioGuard/frontend
flutter run
```

**Option B: Physical Android Phone**
```bash
adb devices  # Make sure phone is connected
flutter run
```

---

## 🔧 One-Time Configuration

Edit `/home/asiimwe/Projects/AudioGuard/frontend/lib/utils/constants.dart`:

Find this line:
```dart
static const String defaultApiBaseUrl = 'https://api.audioguard.io';
```

Change to:
```dart
// For Android emulator:
static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';

// OR for physical device (replace with your PC's IP):
static const String defaultApiBaseUrl = 'http://192.168.1.100:8000';
```

To find your PC's IP:
```bash
# Linux/Mac
hostname -I | awk '{print $1}'

# Windows
ipconfig | findstr IPv4
```

---

## 📱 Using the App

1. **Launch App** - You should see the home screen
2. **Go to Settings** - Tab at bottom
3. **Set API URL** - Should be pre-filled if you edited constants.dart
4. **Go to Encode** - Tab at bottom
5. **Select Audio File** - Tap "Pick File"
6. **Enter Message** - Type your watermark message
7. **Click Embed** - Backend processes it
8. **See Result** - Confirmation with processing time

---

## ✅ Verify Integration Working

### Check 1: API Response
Look in Flutter logs (bottom of terminal running `flutter run`):
```
[INFO] Encoding audio with message: my-watermark
[INFO] API Response: 200 OK - Watermark embedded successfully
```

### Check 2: Backend Logs
In backend terminal, you should see:
```
INFO:     POST /api/v1/encode HTTP/1.1" 200
INFO:     Processing audio file...
INFO:     Watermark embedded in 2.3s
```

### Check 3: File Created
After encoding, you should see files in:
```
Android: /sdcard/DCIM/AudioGuard/
Desktop: /tmp/audioguard_outputs/
```

---

## 🐛 Quick Troubleshooting

**Q: "API server is unreachable"**
- Check if backend is running - Start it in Terminal 1
- Check your IP address - Update constants.dart
- Check firewall - Ensure port 8000 is open

**Q: "No file selected"**
- App needs permission - Grant permissions when prompted
- No audio files? - Put .wav or .mp3 files in phone storage

**Q: "Connection timeout"**
- Backend crashed? - Check backend terminal for errors
- Check if backend is still running

**Q: "Backend won't start"**
- Dependencies missing? - Run: pip install -r requirements.txt
- Port 8000 in use? - Use different port

---

## 📊 What's Happening Behind the Scenes

```
Your Phone/Emulator          Your Computer
     ┌──────────┐               ┌──────────┐
     │ Flutter  │               │  FastAPI │
     │   App    │               │ Backend  │
     └──────────┘               └──────────┘
         │                          │
         │  Select Audio File       │
         ├─────────────────────────►│
         │  /api/v1/encode          │
         │                          │
         │  [Processing Audio]      │
         │                          │
         │◄─────────────────────────┤
         │  Watermarked File        │
         │  + Confidence Score      │
         │
      [Success! ✅]
```

---

## 📚 Full Documentation

For complete details:
- **Full Integration Guide**: `FRONTEND_BACKEND_INTEGRATION.md`
- **Detailed Checklist**: `INTEGRATION_CHECKLIST.md`
- **Backend Docs**: `backend/PHASE_4_COMPLETE.md`
- **Frontend Docs**: `frontend/FLUTTER_PHASE5_COMPLETE.md`
- **API Endpoints**: `backend/api/server.py`

---

**Ready? Start with Step 1! 🚀**
