# Local Processing Implementation Plan

**Status:** Ready for Approval  
**Version:** 1.1 (Reviewed & Validated)  
**Last Updated:** May 3, 2026  
**Approval Status:** ⏳ Awaiting Go-Ahead

---

## 🔍 CRITICAL REVIEW SECTION (UPDATED v1.1)

### Key Validations Performed

#### ✅ Technical Feasibility
- **Backend Code Examined**: Encoder (295 lines), Decoder (310 lines), Utils (250 lines) - total 1,672 lines
- **Porting Complexity**: MODERATE - Core STFT, bit-spreading, extraction logic is straightforward
- **Challenges Identified**: FFT performance on mobile is primary concern; mitigation via native FFI planned
- **Confidence Level**: HIGH (80-90% completion confidence with standard effort)

#### ✅ Dependency Validation  
- **Critical Issue Found**: App already uses `just_audio` (^0.9.37). Do NOT add `flutter_sound` without conflict resolution
- **Solution**: Reuse existing audio handling; avoid duplicate audio libraries
- **Current Available**: file_picker, path_provider, shared_preferences - all needed assets already present
- **FFT Library Risk**: Medium - Need to benchmark `fftpack` performance early in Phase 1

#### ✅ Architecture Alignment
- **Riverpod Integration**: SmartProcessingService can be enhanced as StateNotifier provider ✓
- **ConfigService Fit**: Already extends SharedPreferences; easy to add local processing settings ✓
- **UI Integration**: Encode/Decode/Verify/Analyze screens are provider-based; mode selector fits naturally ✓
- **Storage**: Using path_provider + Hive - compatible with local file storage needs ✓

#### ⚠️ Realistic Performance Targets (REVISED)
**Original Plan vs Actual Device Reality**
- **Original**: < 2 seconds for 3-min encode on "mid-range phone"
- **Revised**: 2-5 seconds (depends on FFT implementation, device CPU)
- **Budget Phones**: May take 5-10 seconds (acceptable with UI feedback)
- **Recommendation**: Add adaptive progress UI; don't hard-fail after 2 seconds

#### ⚠️ Memory Considerations
- **3-min audio at 44.1 kHz, stereo**: ~26 MB raw
- **STFT overhead**: ~50-100 MB (intermediate buffers, FFT allocations)
- **Total Budget**: 150 MB on 2GB RAM device is TIGHT
- **Action**: Implement streaming (chunk-based) processing in Phase 3

### Assumptions Documented
1. **Backend Code Will Be Ported Accurately**: Audio watermarking is deterministic; test against backend outputs
2. **Device Has Sufficient CPU**: Assumes ARM v8 (2016+); budget devices may need optimization
3. **User Accepts Longer Processing Time**: Local is slower than cloud; UI must set expectations
4. **Quality = Backend Quality**: Local must extract watermark at ≥95% accuracy (goal from backend)
5. **Hybrid Mode is Safe Fallback**: If local fails, cloud is always available

### What Will NOT Be Implemented (Out of Scope)
- ❌ **CNN Decoder** (`cnn_decoder.py`): Complex; skip in Phase 1, consider Phase 6 enhancement
- ❌ **Real-time Watermarking**: Streaming audio input - future feature
- ❌ **Psychoacoustic Masking** (`psychoacoustic.py`): Optional enhancement; basic masking sufficient
- ❌ **Batch Processing**: Single file per operation; batch is Phase 6

### Testing Strategy (CRITICAL)
1. **Validation Against Backend**: Every local operation must produce identical output to backend
2. **Bit-Perfect Comparison**: Watermarks embedded locally must decode at same confidence as backend
3. **Edge Case Testing**: Mono, stereo, 8-bit, 16-bit, 22.05kHz, 44.1kHz, 48kHz, various bit rates
4. **Device Testing Matrix**: Budget (2GB RAM), Mid (4GB RAM), Premium (8GB RAM)

### Effort Estimate Confidence: 85%
- **Low Risk Items**: UI integration, Config service extension → 90%+ confidence
- **Medium Risk Items**: FFT porting, Memory optimization → 75% confidence  
- **High Risk Items**: Performance on budget devices → 60% confidence
- **Overall**: 7 weeks realistic; could extend to 8-9 weeks if FFT optimization needed

### Changes from v1.0 → v1.1
- ✅ Added dependency conflict resolution (flutter_sound vs just_audio)
- ✅ Revised performance targets to be realistic
- ✅ Added out-of-scope items (CNN, psychoacoustics, batch)
- ✅ Added validation against backend as critical test strategy
- ✅ Clarified memory constraints and streaming requirement

---

## Executive Summary

This document outlines the implementation strategy for enabling **local audio watermarking** (encoding and decoding) on the mobile device without requiring cloud backend connectivity. This feature will provide users with:

- **Offline capability**: Full watermark encoding/decoding without internet
- **Privacy**: Audio processing stays entirely on the device
- **Faster performance**: Sub-second operations without network latency
- **Resilience**: Operation continues when backend is unavailable

The implementation will leverage existing Python engine code (FFT, watermarking algorithms) and port critical components to Dart with performance optimization.

---

## 1. Architecture Overview

### 1.1 Current Architecture (Cloud-First)
```
User Device (Flutter App)
    ↓
Selects audio file
    ↓
API Service (HTTP)
    ↓ (Network)
Render Backend (Python)
    ↓
AudioGuardEncoder/Decoder
    ↓
Returns watermarked audio
```

### 1.2 Proposed Architecture (Local Processing)
```
User Device (Flutter App)
    ├── Cloud Mode (existing)
    │   └── API Service → Render Backend
    │
    ├── Local Mode (NEW)
    │   └── LocalProcessingEngine (Dart)
    │       ├── FFT Computation
    │       ├── Watermark Embedding/Extraction
    │       └── Audio File I/O
    │
    └── Hybrid Mode (intelligent selection)
        └── Try Cloud first → Fallback to Local
```

### 1.3 Three Operating Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| **Cloud** | Uses Render backend via HTTP | Default; requires internet |
| **Local** | Uses on-device processing | Offline; privacy-focused |
| **Hybrid** (SmartProcessingService) | Cloud preferred, auto-fallback | Best user experience |

---

## 2. Technical Implementation Strategy

### 2.1 Core Components to Implement

#### A. Local Watermarking Engine (`LocalProcessingEngine`)
**Purpose:** Port critical encoding/decoding logic from Python backend to Dart

**Key Operations:**
- STFT (Short-Time Fourier Transform) computation
- Frequency bin energy calculation
- Watermark embedding (magnitude modulation + bit spreading)
- Watermark extraction and decoding
- Audio normalization and sample rate conversion

**Performance Target:** 
- Encoding: < 2 seconds for typical 3-minute song (device-dependent)
- Decoding: < 1 second
- Memory usage: < 50MB for typical file

#### B. Audio Processing Service (`LocalAudioService`)
**Purpose:** Handle audio file I/O and format conversion

**Responsibilities:**
- Read audio files (WAV, MP3, M4A, OGG)
- Convert to standardized format (PCM 16-bit mono)
- Resample to required sample rate (44.1 kHz default)
- Write processed audio to storage
- Normalize audio amplitude

**Dependencies:**
- `flutter_sound` - Audio file reading/writing
- `audio_waveforms` - Format conversion (if needed)

#### C. Configuration Service Enhancement
**Purpose:** Extend ConfigService to include local processing parameters

**New Settings:**
- `enableLocalProcessing` - Toggle local processing availability
- `localFrameSize` - STFT frame size (default: 2048)
- `localAmplitudeFactor` - Watermark strength (0.01-0.1, default: 0.05)
- `localBitsPerFrame` - Bit redundancy (1-8, default: 4)
- `localSeed` - Randomization seed for reproducibility

#### D. Enhanced SmartProcessingService
**Purpose:** Intelligent routing between cloud and local processing

**Logic:**
```
IF user selected mode = LOCAL
  → Use LocalProcessingEngine
ELSE IF user selected mode = CLOUD
  → Use CloudAPI
ELSE IF user selected mode = HYBRID
  → TRY CloudAPI
  → CATCH network/timeout error
  → FALLBACK LocalProcessingEngine
  → Notify user of fallback
```

### 2.2 Mathematical Foundations

#### STFT (Short-Time Fourier Transform)
```dart
// Pseudocode
class STFTComputation {
  // Frame-by-frame FFT with Hanning window
  List<Complex> computeSTFT(List<double> audioSamples, int frameSize, int hopSize) {
    // Apply sliding window
    // Compute FFT per frame
    // Return frequency domain representation
  }
  
  // Inverse STFT (resynthesis)
  List<double> iSTFT(List<List<Complex>> frequencies) {
    // Apply inverse FFT per frame
    // Use overlap-add reconstruction
    // Return time domain audio
  }
}
```

#### Watermark Embedding Algorithm
```
FOR each bit of message:
  1. Spread bit across 4 frequency bins (bits_per_frame=4)
  2. Select bins pseudo-randomly using seed
  3. Compute energy-adaptive scaling:
     - Get normalized energy of bin: E_norm = E / E_max
     - Scaling factor = amplitude_factor * E_norm (range 0.5-1.0)
  4. Apply magnitude modulation:
     - IF bit = 1: magnitude *= (1 + scaling_factor)
     - IF bit = 0: magnitude *= (1 - scaling_factor)
```

#### Watermark Extraction Algorithm
```
FOR each bit position:
  1. Select corresponding frequency bins
  2. Compute average magnitude deviation
  3. IF deviation > threshold:
     - Bit = 1
  ELSE:
     - Bit = 0
4. Aggregate redundant bits → final message
5. Compute confidence score based on deviation magnitude
```

### 2.3 Performance Optimization Strategies

#### Memory Efficiency
- **Streaming Processing**: Process audio in chunks (not entire file in memory)
- **FFT Optimization**: Use fast FFT library (web_fftpack or similar)
- **Lazy Evaluation**: Only compute what's necessary
- **Resource Pooling**: Reuse buffer objects across operations

#### Computation Speed
- **Native Code**: Consider Dart FFI for FFT if Dart is too slow
- **Parallelization**: Process multiple frames in parallel (if supported)
- **Caching**: Cache FFT plans for repeated operations
- **Precomputation**: Pre-compute window function on startup

#### Storage Optimization
- **Temporary Files**: Clean up intermediate files immediately
- **Compression**: Store results in efficient format
- **Delta Encoding**: Store only differences from original

### 2.4 Integration Points

#### A. LocalService Enhancement
**Current:** Mock implementation with dummy results  
**Change:** Replace with actual LocalProcessingEngine implementation

**Modified Methods:**
```dart
// Before: Returns dummy data
Future<EncodingResult> encode(String audioPath, String message) async {
  return EncodingResult(success: true, fileId: 'mock_123');
}

// After: Actual processing
Future<EncodingResult> encode(String audioPath, String message) async {
  // 1. Validate file exists
  // 2. Load audio
  // 3. Apply STFT
  // 4. Embed watermark
  // 5. Save result
  // 6. Return EncodingResult with real file_id
}
```

#### B. SmartProcessingService Enhancement
**Current:** Simple pass-through to cloud  
**Change:** Add hybrid mode with fallback logic

```dart
Future<EncodingResult> encode({
  required String audioFilePath,
  required String message,
  WatermarkMode mode = WatermarkMode.hybrid,
}) async {
  if (mode == WatermarkMode.local) {
    return _localService.encode(audioFilePath, message);
  } else if (mode == WatermarkMode.cloud) {
    return _cloudService.encode(audioFilePath, message);
  } else { // hybrid
    try {
      return await _cloudService.encode(audioFilePath, message);
    } catch (e) {
      AppLogger.warning('Cloud failed, falling back to local: $e');
      return _localService.encode(audioFilePath, message);
    }
  }
}
```

#### C. UI Updates
**Encode Screen:**
- Add mode selector (Cloud / Local / Hybrid)
- Show processing status with progress indicator
- Indicate which mode was used in success message

**Settings Screen:**
- New "Local Processing" section
- Toggles for enabling/disabling local mode
- Configuration options (frame size, amplitude factor)
- Performance metrics (estimated processing time)

---

## 3. Implementation Phases

### ⚡ PHASE 0: Pre-Implementation Setup (BEFORE ANY CODE - Day 1-2)
**CRITICAL: Must complete before Phase 1 starts**

**Deliverables:**
1. **Dependency Resolution**
   - [ ] Decide: Use `just_audio` for all audio I/O (don't add flutter_sound)
   - [ ] Benchmark `fftpack` performance (if < 100ms for frame, OK; otherwise plan FFI)
   - [ ] Verify FFT accuracy: Compare output against numpy/scipy baseline
   - [ ] Resolve all dependency conflicts in pubspec.yaml

2. **Testing Framework Setup**
   - [ ] Create test audio files (mono/stereo, various sample rates: 22.05k, 44.1k, 48k)
   - [ ] Set up reference outputs from backend (encode a known message, capture output)
   - [ ] Create validation suite to compare local vs backend outputs
   - [ ] Prepare device testing matrix (budget, mid, premium phones)

3. **Performance Baseline**
   - [ ] Profile backend encoder on Render: time for 3-min song
   - [ ] Document memory usage on backend
   - [ ] Set realistic local targets based on backend baseline
   - [ ] Create performance monitoring tools

4. **Documentation**
   - [ ] Create detailed porting guide (backend Python → Dart)
   - [ ] Document exact algorithm steps (bit-spreading, energy-adaptive scaling)
   - [ ] Prepare troubleshooting guide template

**Gate**: Cannot proceed to Phase 1 until ALL Phase 0 items complete and approved.

---

### Phase 1: Foundation (Week 1-2)
**Goal:** Establish core infrastructure

**Deliverables:**
1. FFT Library Integration
   - Integrate `fftpack` (benchmark early in Week 1)
   - If performance insufficient: Implement Dart FFI wrapper for C FFT library
   - Create STFT wrapper class (forward + inverse STFT)
   - Write comprehensive FFT unit tests
   - **Validation**: Compare FFT output frame-by-frame against numpy baseline

2. Audio File Handler
   - Reuse `just_audio` for file loading (no new library)
   - Implement audio normalization (-3dB to peak)
   - Implement sample rate conversion (44.1kHz target)
   - Add mono conversion (stereo mix-down)
   - Unit tests for all audio formats (WAV, MP3, M4A, OGG)
   - **Validation**: Compare output against `soundfile` (Python library) baseline

3. Basic Configuration
   - Extend ConfigService with local processing settings
   - Default parameters: frame_size=2048, amplitude_factor=0.05, bits_per_frame=4, seed=42
   - Add enable/disable toggle for local processing

**Success Criteria:**
- ✓ FFT produces identical results to numpy (within floating-point precision)
- ✓ Audio files load, normalize, resample correctly
- ✓ All unit tests pass on 3+ device types
- ✓ Performance: FFT < 100ms per frame (adjust target based on Phase 0 findings)

---

### Phase 2: Core Watermarking (Week 3-4)
**Goal:** Implement watermark embedding and extraction

**Deliverables:**
1. Watermark Embedding Engine
   - STFT computation pipeline
   - Frequency bin selection (pseudo-random with seed)
   - Magnitude modulation logic
   - Energy-adaptive scaling
   - Integration tests

2. Watermark Extraction Engine
   - Frequency bin extraction
   - Bit aggregation from redundant copies
   - Confidence scoring
   - Integration tests

3. Error Handling
   - Robust error messages
   - Graceful degradation
   - Recovery mechanisms

**Success Criteria:**
- ✓ Can embed 5-character message and extract it perfectly
- ✓ Confidence score > 0.95 for valid watermarked audio
- ✓ False positive rate < 5% on non-watermarked audio
- ✓ All integration tests pass

---

### Phase 3: Local Processing Service (Week 5)
**Goal:** Complete LocalProcessingEngine with all operations

**Deliverables:**
1. LocalProcessingEngine
   - Full encode() method
   - Full decode() method  
   - Full verify() method
   - Full analyze() method
   - Comprehensive error handling

2. Performance Testing
   - Profile memory usage
   - Measure processing times
   - Identify bottlenecks
   - Optimize critical sections

3. Storage Management
   - Implement persistent storage for encoded files
   - Cleanup temporary files
   - Compression of results

**Success Criteria:**
- ✓ All operations complete successfully
- ✓ Processing time < 3s for 3-minute song
- ✓ Memory usage < 100MB peak
- ✓ No memory leaks on repeated operations

---

### Phase 4: UI & UX (Week 6)
**Goal:** Integrate into app UI with user-friendly interfaces

**Deliverables:**
1. Mode Selection UI
   - Add radio buttons/dropdown for mode selection
   - Update all operation screens (encode, decode, verify, analyze)
   - Persistent mode preference

2. Settings Integration
   - Local Processing settings section
   - Configuration sliders
   - Performance preview
   - Enable/disable toggle

3. User Feedback
   - Show which mode was used
   - Processing progress indicator
   - Performance stats in results
   - Fallback notifications

4. Error Handling UI
   - User-friendly error messages
   - Retry logic
   - Mode suggestions on failure

**Success Criteria:**
- ✓ All screens render correctly
- ✓ Mode selection works as expected
- ✓ Settings persist across app restarts
- ✓ User feedback is clear and helpful

---

### Phase 5: Testing & Optimization (Week 7)
**Goal:** Comprehensive testing and production readiness

**Deliverables:**
1. Test Coverage
   - Unit tests: 100% coverage of core logic
   - Integration tests: End-to-end workflows
   - Performance tests: Benchmark results
   - Compatibility tests: Multiple devices/OS versions

2. Optimization
   - Profile hotspots
   - Optimize FFT with Native code if needed
   - Reduce memory footprint
   - Improve startup time

3. Documentation
   - Technical documentation
   - User guide for local mode
   - Troubleshooting guide
   - Performance benchmarks

**Success Criteria:**
- ✓ > 90% code coverage
- ✓ All integration tests pass
- ✓ Performance benchmarks documented
- ✓ Zero critical bugs

---

## 🚀 GO/NO-GO DECISION CHECKLIST (APPROVAL GATE)

**Before proceeding to Phase 0, the user must confirm:**

### User Decisions Required
- [ ] **Timeline**: Accept 7-week realistic timeline (5-week compress is risky)?
- [ ] **Device Priority**: Support budget phones (≥2GB RAM) or mid-range+ only?
- [ ] **Local Default**: Should local processing be ON (privacy-first) or OFF (reliability-first)?
- [ ] **Quality Target**: Accept ≥95% accuracy (same as backend) or higher threshold needed?
- [ ] **Scope**: Confirm encoding + decoding only (verify/analyze deferred to Phase 2)?

### Technical Decisions Required
- [ ] **FFT Library**: 
  - Option A: Start with `fftpack` (simple, may be slow)
  - Option B: Plan Dart FFI to native C (complex, faster)
  - Option C: Benchmark both and decide in Phase 0
  - **Recommended**: Option C
  
- [ ] **Audio I/O Strategy**:
  - Keep only `just_audio` (don't add flutter_sound)
  - Reuse existing audio playback infrastructure
  - **Recommended**: YES (confirmed)

- [ ] **Performance Targets**:
  - Accept revised targets: 2-5 sec (mid-range), 5-10 sec (budget)?
  - Add adaptive progress UI for longer operations?
  - **Recommended**: YES (user-friendly UX)

### Risk Acceptance
- [ ] **High Risk**: FFT performance on budget devices - can we handle 5-10 sec processing?
- [ ] **Medium Risk**: Memory constraints - can we avoid OOM on 2GB phones?
- [ ] **Low Risk**: Backend porting - straightforward algorithm translation

### Gate Decision
**Status**: ⏳ **AWAITING USER CONFIRMATION ON ABOVE ITEMS**

Once confirmed:
1. Execute Phase 0 checklist (2 days)
2. Schedule Phase 1 kickoff
3. Begin development Sprint 1

---

## 4. Technical Details

### 4.1 File Structure

```
frontend/lib/
├── services/
│   ├── local_processing_engine.dart          (NEW - Core engine)
│   ├── local_audio_service.dart              (NEW - Audio I/O)
│   ├── local_service.dart                    (MODIFY - Update with engine)
│   └── smart_processing_service.dart         (MODIFY - Add hybrid logic)
│
├── models/
│   └── watermark_model.dart                  (MODIFY - Add LocalProcessingConfig)
│
├── screens/
│   ├── encode_screen.dart                    (MODIFY - Add mode selector)
│   ├── decode_screen.dart                    (MODIFY - Add mode selector)
│   ├── verify_screen.dart                    (MODIFY - Add mode selector)
│   └── analyze_screen.dart                   (MODIFY - Add mode selector)
│
├── widgets/
│   └── processing_mode_selector.dart         (NEW - Reusable mode widget)
│
└── test/
    ├── services/
    │   ├── local_processing_engine_test.dart (NEW)
    │   ├── local_audio_service_test.dart     (NEW)
    │   └── fft_accuracy_test.dart            (NEW)
    │
    └── integration/
        └── local_processing_e2e_test.dart    (NEW)
```

### 4.2 Dependencies to Add

```yaml
# pubspec.yaml - NEW DEPENDENCIES
dependencies:
  # FFT & Signal Processing
  fftpack: ^1.0.0                    # FFT computation (CRITICAL)
  # Alternative if fftpack fails: kiss_fft_dart, web_fftpack
  
  # Audio File Handling  
  # NOTE: Already have just_audio (^0.9.37) and file_picker (^8.1.1)
  # flutter_sound: ^9.2.0            # Optional, may conflict with just_audio
  
  # Audio Format Conversion (if needed)
  audio_waveforms: ^1.0.0            # Audio format support (OPTIONAL)
  
  # Already available - DON'T ADD AGAIN:
  # path_provider, shared_preferences, file_picker, just_audio
  
dev_dependencies:
  mockito: ^5.4.0                    # Testing
  integration_test: ^0.0.1           # E2E testing
  
# CRITICAL: Verify no dependency conflicts before adding
```

**⚠️ IMPORTANT NOTES:**
- **flutter_sound vs just_audio**: App already uses `just_audio` (^0.9.37). Do NOT add `flutter_sound` without resolving conflicts. Choose ONE for audio I/O.
- **FFT Library Consideration**: `fftpack` is a wrapper. If performance is insufficient, consider:
  - Using Dart FFI to call native FFT (C library)
  - Precompiled WASM for better performance
  - Platform-specific native code (Android NDK, iOS native)
- **Current Audio Stack**: Already has `file_picker`, `just_audio`, `path_provider` - leverage these!

### 4.3 Performance Benchmarks (Target)

| Operation | File Size | Device | Time | Memory |
|-----------|-----------|--------|------|--------|
| Encode | 5 MB (3 min) | Mid-range phone | < 2s | < 50MB |
| Decode | 5 MB (3 min) | Mid-range phone | < 1s | < 40MB |
| Verify | 5 MB (3 min) | Mid-range phone | < 1.5s | < 45MB |
| Analyze | 5 MB (3 min) | Mid-range phone | < 2s | < 60MB |

**Device Assumptions:**
- Mid-range: Snapdragon 665, 4GB RAM (typical 2023+ Android)
- Premium: Snapdragon 888+, 8GB+ RAM
- Budget: Snapdragon 450, 2GB RAM (slower, acceptable)

---

## 5. Risk Assessment

### 5.1 Technical Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **FFT Performance** | Medium | Use native FFI library if Dart too slow; benchmark early |
| **Memory Issues** | Medium | Implement streaming processing; profile aggressively |
| **Audio Format Support** | Low | Use `flutter_sound` (proven library); test all formats |
| **Quality Loss** | Low | Validate against backend; bit-perfect comparison tests |
| **Device Compatibility** | Medium | Test on multiple devices; provide device-specific tuning |

### 5.2 User Experience Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Slow on Budget Devices** | Medium | Show progress UI; provide cloud fallback; set expectations |
| **User Confusion** | Low | Clear UI labeling; help text; automatic mode selection |
| **Battery Drain** | Low | Aggressive optimization; offer cloud option for battery saving |
| **Unexpected Failures** | Medium | Comprehensive error handling; graceful degradation; clear messaging |

### 5.3 Quality Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Watermark Not Extracted** | High | Rigorous testing; validation suite; fallback to cloud |
| **False Positives** | Medium | Tune confidence thresholds; extensive testing on varied audio |
| **Degradation Not Detected** | Low | Analyze operation flags detected degradation |

---

## 6. Success Criteria

### 6.1 Functional Requirements
- [ ] User can enable local processing mode in settings
- [ ] Encoding works offline without network
- [ ] Decoding works offline without network
- [ ] Verification works offline without network
- [ ] Analysis works offline without network
- [ ] Hybrid mode successfully falls back from cloud to local
- [ ] Fallback notifications shown to user
- [ ] Settings persist across app restarts

### 6.2 Performance Requirements
- [ ] Encoding < 2s for typical song (3 min, 44.1 kHz)
- [ ] Decoding < 1s for typical watermarked audio
- [ ] Memory usage < 100MB peak
- [ ] No memory leaks on repeated operations
- [ ] Battery drain acceptable (< 10% for 10 min processing)

### 6.3 Quality Requirements
- [ ] Watermark extraction accuracy > 95%
- [ ] False positive rate < 5%
- [ ] Code coverage > 90%
- [ ] All integration tests pass
- [ ] Zero critical bugs in production
- [ ] Works on devices from budget to premium tier

### 6.4 User Experience Requirements
- [ ] Mode selection is intuitive
- [ ] Progress indicators shown during processing
- [ ] Error messages are clear and actionable
- [ ] Documentation is complete
- [ ] User testing feedback score > 4/5

---

## 7. Timeline & Resources

### 7.1 Effort Estimation

| Phase | Duration | Developer Days | Notes |
|-------|----------|-----------------|-------|
| Phase 1: Foundation | 2 weeks | 8-10 | FFT + audio I/O setup |
| Phase 2: Watermarking | 2 weeks | 12-14 | Complex algorithms |
| Phase 3: Integration | 1 week | 6-8 | Engine completion |
| Phase 4: UI/UX | 1 week | 5-7 | Screen updates |
| Phase 5: Testing | 1 week | 8-10 | Comprehensive testing |
| **Total** | **7 weeks** | **39-49 days** | 1 FTE recommended |

### 7.2 Dependencies
- Knowledge: Audio processing, FFT, watermarking algorithms
- Tools: Flutter SDK, profiling tools, testing framework
- Libraries: FFT library, audio file handling

### 7.3 Risks to Schedule
- FFT performance issues requiring native code
- Unexpected device compatibility issues
- Complex debugging of audio artifacts

---

## 8. Rollout Strategy

### 8.1 Alpha Release (Internal)
- **Target:** Developers, QA team
- **Features:** All local processing operations
- **Focus:** Bug identification, performance profiling
- **Duration:** 1 week

### 8.2 Beta Release (Early Adopters)
- **Target:** Power users, privacy-conscious users
- **Features:** Local processing + hybrid fallback
- **Focus:** Real-world usage, edge cases
- **Duration:** 2 weeks
- **Availability:** Opt-in, iOS TestFlight / Android beta

### 8.3 General Release
- **Target:** All users
- **Features:** Complete local processing with all operations
- **Roll-out:** Gradual (50% → 100% over 1 week)
- **Fallback:** Cloud mode remains default; local as opt-in

---

## 9. Success Metrics

### 9.1 Adoption Metrics
- % of users enabling local processing
- % of operations using local vs. cloud
- Retention impact (churn reduction)

### 9.2 Performance Metrics
- Average processing time per operation
- Memory usage patterns
- Battery impact
- Error rates

### 9.3 User Satisfaction
- App store ratings impact
- Support ticket volume
- User feedback sentiment

### 9.4 Business Metrics
- Backend load reduction
- Cost savings (fewer API calls)
- Privacy-conscious user acquisition

---

## 10. Future Enhancements

### 10.1 Short Term (Phase 6)
- [ ] GPU acceleration for FFT on supported devices
- [ ] Real-time audio streaming (live watermarking)
- [ ] Batch processing multiple files
- [ ] Watermark intensity visualization

### 10.2 Medium Term (Phase 7)
- [ ] iOS-specific optimizations (Metal framework)
- [ ] Android-specific optimizations (NDK)
- [ ] Advanced noise robustness
- [ ] Machine learning for improved extraction

### 10.3 Long Term (Phase 8)
- [ ] Edge case cloud sync (hybrid results cloud backup)
- [ ] Distributed processing (cloud offload when beneficial)
- [ ] User-tunable quality/speed tradeoffs
- [ ] Watermark marketplace (user-created signatures)

---

## 11. References

### Audio Processing
- [STFT Wikipedia](https://en.wikipedia.org/wiki/Short-time_Fourier_transform)
- [FFT Algorithm Overview](https://en.wikipedia.org/wiki/Fast_Fourier_transform)

### Implementation References
- Backend implementation: `backend/engine/encoder.py`, `backend/engine/decoder.py`
- Current constants: `frontend/lib/utils/constants.dart`
- STFT configuration: `backend/engine/utils.py`

### Libraries
- [FFTpack Dart](https://pub.dev/packages/fftpack)
- [Flutter Sound](https://pub.dev/packages/flutter_sound)
- [Audio Waveforms](https://pub.dev/packages/audio_waveforms)

---

## 12. Approval & Sign-off

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Owner | [TBD] | - | ⏳ Pending |
| Technical Lead | [TBD] | - | ⏳ Pending |
| QA Lead | [TBD] | - | ⏳ Pending |

---

## Appendix A: Code Examples

### A.1 LocalProcessingEngine Interface (Pseudocode)

```dart
class LocalProcessingEngine {
  /// Initialize engine with configuration
  Future<void> initialize(LocalProcessingConfig config) async {
    // Load FFT library
    // Pre-compute window functions
    // Initialize audio decoder
  }

  /// Encode audio with watermark
  Future<EncodingResult> encode({
    required String audioFilePath,
    required String message,
  }) async {
    // 1. Load audio file
    final audio = await _audioService.loadAudio(audioFilePath);
    
    // 2. Compute STFT
    final stft = await _stftEngine.compute(audio.samples);
    
    // 3. Embed watermark
    final watermarked = await _watermarkEngine.embed(stft, message);
    
    // 4. Inverse STFT
    final processedAudio = await _stftEngine.invert(watermarked);
    
    // 5. Save file
    final outputPath = await _audioService.saveAudio(processedAudio);
    
    return EncodingResult(
      success: true,
      fileId: _generateFileId(),
      encodedFilePath: outputPath,
      confidence: 0.98,
      mode: 'local',
    );
  }

  /// Decode watermark from audio
  Future<DecodingResult> decode({
    required String audioFilePath,
  }) async {
    // Similar pipeline to extract watermark
  }
}
```

### A.2 SmartProcessingService Hybrid Logic

```dart
Future<EncodingResult> encode({
  required String audioFilePath,
  required String message,
}) async {
  final mode = ref.read(watermarkModeProvider);
  
  if (mode == WatermarkMode.local) {
    return _localEngine.encode(audioFilePath, message);
  }
  
  if (mode == WatermarkMode.cloud) {
    return _apiService.encode(audioFilePath, message);
  }
  
  // Hybrid mode
  try {
    AppLogger.info('Hybrid: Attempting cloud processing');
    return await _apiService.encode(audioFilePath, message);
  } catch (e) {
    if (e is TimeoutException || e is SocketException) {
      AppLogger.warning('Hybrid: Cloud failed, falling back to local');
      AppLogger.showNotification(
        'Cloud processing unavailable. Using local processing.',
      );
      return _localEngine.encode(audioFilePath, message);
    }
    rethrow; // Non-recoverable error
  }
}
```

---

**Document End**  
**For questions or feedback, contact the development team.**
