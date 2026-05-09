# AudioGuard Phase 2 Roadmap

## Overview

Phase 1 MVP successfully delivered encode, verify, and analyse functionality with >99% accuracy. Phase 2 focuses on **production hardening** and **classical decoder redesign** to achieve >95% message recovery accuracy.

This document outlines technical priorities, milestones, and success criteria for Phase 2.

---

## Phase 1 → Phase 2 Transition

### What Worked Well (Phase 1)

✅ Multi-resolution STFT embedding (3x redundancy across frame sizes)  
✅ Reed-Solomon error correction (20% overhead, proven robust)  
✅ Verification accuracy >99% on freshly encoded audio  
✅ Analysis endpoint provides reliable spectral metadata  
✅ Backend API coherent, tests passing, CI/CD working  
✅ Flutter frontend stable on iOS/Android  

### What Needs Improvement (Phase 2)

⚠️ **Decoder accuracy ~50%** (chance level, not viable for production)  
⚠️ Single-worker deployment (in-process job store)  
⚠️ Ephemeral storage (files lost on restart)  
⚠️ No rate limiting or API key authentication  
⚠️ Limited monitoring/observability for production  

---

## Phase 2 Milestones

### M1: Decoder Redesign (Primary Task)

**Goal:** Achieve >95% bit accuracy on message recovery.

#### Current State Analysis

**Problem:** Classical decoder using z-score normalization per frame achieves only ~50% bit accuracy even on freshly encoded audio.

**Root Cause:** Energy-deviation model assumptions:
1. Assumes watermarked bins have higher energy than baseline → **FALSE** in practice
2. Assumes non-watermarked bins follow a known distribution → **Too simplistic**, natural STFT variation is complex
3. Per-frame z-score normalization → Doesn't account for time-domain coherence

**Confidence Paradox:**
- High confidence scores (~0.95) from Barker-13 sync detection
- But extracted bits are near-random (BER ~0.50)
- Suggests sync is found, but bit extraction heuristic is fundamentally flawed

#### Solution Option 1: CNN-Based Extraction (Recommended)

**Approach:**
1. Generate synthetic training data
   - Encode known messages at various amplitudes (0.01–1.0)
   - Add noise/compression artifacts
   - Create 10k+ labeled encode/decode pairs
2. Design CNN architecture
   - Input: Magnitude STFT (multi-resolution)
   - Output: Per-bin bit probability (0.0–1.0)
   - Loss: Binary cross-entropy with class weighting
3. Integrate into `message_codec.py`
   - Replace z-score extraction with CNN forward pass
   - Use pre-trained weights
   - Fallback to classical method if model unavailable

**Pros:**
- Learns actual signal model from data
- Handles natural STFT variation
- Generalizes to different audio types

**Cons:**
- Requires GPU for inference (or quantization for mobile)
- Model size overhead (~10-20 MB)
- Inference latency increase (classical: 50ms → CNN: 100-200ms)

**Timeline:** 2-3 weeks (data generation + training + integration)

#### Solution Option 2: Heuristic Redesign (Fast Path)

**Approach:**
1. Analyze per-bin energy statistics in high-quality watermarked audio
   - Does embedding actually increase/decrease energy?
   - What's the statistical distribution of "watermarked" vs "non-watermarked" bins?
   - Is there time-domain coherence?
2. New heuristic candidates:
   - Normalized correlation with expected modulation pattern
   - Bayesian model: P(watermarked | observed magnitude)
   - Phase coherence constraints across frames
3. Tune on validation set for >95% accuracy
4. Replace `_estimate_bit_energy()` with new logic

**Pros:**
- Fast to implement (1 week)
- No external dependencies
- Works without training data

**Cons:**
- May not generalize as well as CNN
- Risk of overfitting to specific audio types
- Still empirical rather than principled

**Timeline:** 1-2 weeks

#### Recommendation

**Start with Heuristic Redesign (Option 2)** for quick wins; if accuracy plateaus <90%, pivot to CNN (Option 1).

**Decision Gate:** After 1 week of heuristic tuning:
- If accuracy >90% → Continue heuristic path, optimize for production
- If accuracy <85% → Switch to CNN training

---

### M2: Production Hardening (Parallel Task)

**Goal:** Enable multi-worker, secure, observable production deployments.

#### Task 2.1: Redis Job Store

**Current Issue:** In-process `_JOBS` dict not thread-safe or distributed-safe.

**Implementation:**
1. Replace `_JOBS` with Redis backend
   ```python
   import redis
   
   redis_client = redis.Redis(host='localhost', port=6379)
   
   # Store job metadata
   redis_client.setex(f"job:{job_id}", 3600, json.dumps(job_data))
   ```
2. Update `api/main.py`:
   - GET `/api/v1/jobs/{job_id}` queries Redis
   - Background tasks update Redis on completion
3. Migrate file storage to S3 or GCS
   - Replace `/tmp/audioguard_storage/` with cloud storage
   - Generate signed URLs for downloads
4. Update tests to mock Redis

**Timeline:** 1 week  
**Dependencies:** Redis server, S3/GCS credentials

#### Task 2.2: Rate Limiting & Authentication

**Current Issue:** No rate limiting; unauthenticated API access.

**Implementation:**
1. FastAPI SlowAPI middleware
   ```python
   from slowapi import Limiter
   
   limiter = Limiter(key_func=get_remote_address)
   app.state.limiter = limiter
   
   @limiter.limit("100/minute")
   async def encode_endpoint(): ...
   ```
2. Optional API key authentication
   ```python
   from fastapi.security import APIKeyHeader
   
   api_key_header = APIKeyHeader(name="X-API-Key")
   ```
3. Document in API reference

**Timeline:** 3 days  
**Testing:** Add rate limit verification tests

#### Task 2.3: Observability & Monitoring

**Current Issue:** Limited logging/metrics for production debugging.

**Implementation:**
1. Add structured logging with OpenTelemetry
   ```python
   from opentelemetry import trace
   
   tracer = trace.get_tracer(__name__)
   with tracer.start_as_current_span("encode_operation"):
       # log span events
   ```
2. Export traces to:
   - Jaeger (local development)
   - Datadog/New Relic (production)
3. Add Prometheus metrics
   - Encode/decode/verify latency histograms
   - File size distribution
   - Error rate by endpoint
4. Update deployment docs with observability setup

**Timeline:** 1 week  
**Testing:** Integration tests with mock collectors

#### Task 2.4: Containerization & K8s Support

**Current Issue:** Docker setup basic; no K8s manifests.

**Implementation:**
1. Optimize Dockerfile
   - Multi-stage build to reduce image size
   - Non-root user for security
   - Health check endpoint
2. Create Kubernetes manifests
   - Deployment (4 replicas default)
   - Service (ClusterIP)
   - ConfigMap for environment variables
   - PersistentVolumeClaim for file storage (or cloud storage)
3. Helm chart for easy installation
4. Update deployment docs

**Timeline:** 1 week

---

### M3: Frontend Enhancements

**Goal:** Improve UX and performance for Phase 2.

#### Task 3.1: Decoder UI Feedback

**Current Issue:** Decode endpoint shows high confidence despite low accuracy.

**Implementation:**
1. Update decode result screen to show **confidence caveat**
   ```
   ⚠️ Phase 1 Note: Message recovery accuracy is limited (~50%).
   Full message recovery will be available in Phase 2.
   Consider using Verify endpoint for production use cases.
   ```
2. Add confidence threshold slider for verify
3. Show SNR/BER estimates in analyse screen
4. Document Phase 1 limitations in-app

**Timeline:** 3 days

#### Task 3.2: Offline Mode & Local Caching

**Current Issue:** Requires backend connectivity; no offline fallback.

**Implementation:**
1. Cache recent encode/verify results locally
   ```dart
   final box = await Hive.openBox('audioguard_cache');
   box.put('last_verification_$fileId', result);
   ```
2. Show cached results if backend unavailable
3. Sync cache when connection restored
4. Document offline limitations in README

**Timeline:** 5 days

#### Task 3.3: Batch Operations

**Current Issue:** Can only encode/verify one file at a time.

**Implementation:**
1. Add batch encode/verify UI
2. Background isolate for parallel processing
3. Progress tracking for multiple files
4. Export results as CSV/JSON

**Timeline:** 1 week

---

## Technical Debt (By Priority)

### High Priority (Block Production)

1. ✅ **[DONE - Phase 1]** API contract alignment (Flutter/FastAPI params)
2. ✅ **[DONE - Phase 1]** Security hardening (TLS, file handling, permissions)
3. ✅ **[DONE - Phase 1]** CI/CD pipeline setup (GitHub Actions)
4. 🔄 **[PHASE 2.M1]** Decoder accuracy (<50% → >95%)
5. 🔄 **[PHASE 2.M2]** Multi-worker job store (Redis)
6. 🔄 **[PHASE 2.M2]** Persistent file storage (S3/GCS, not /tmp)

### Medium Priority (Improve UX/Security)

7. 🔄 **[PHASE 2.M2]** Rate limiting (100 req/min per IP)
8. 🔄 **[PHASE 2.M2]** API key authentication
9. 🔄 **[PHASE 2.M3]** Batch operations UI
10. 🔄 **[PHASE 2.M3]** Offline mode & caching

### Low Priority (Nice to Have)

11. 🔄 **[PHASE 2.M3]** Internationalization (i18n) support
12. 🔄 **[PHASE 2.M2]** Advanced monitoring (Prometheus, Grafana)
13. 🔄 **[PHASE 2.M2]** Kubernetes manifests & Helm charts

---

## Success Criteria

### Decoder (M1)

- [ ] Message recovery accuracy >95% on freshly encoded audio
- [ ] Accuracy >80% on compressed (MP3) and resampled audio
- [ ] Latency <200ms per message (classical: <100ms)
- [ ] Tests: 30+ test cases covering audio types, noise, compression

### Production Hardening (M2)

- [ ] Redis job store: distributed queries work across N workers
- [ ] Persistent storage: files survive process restart
- [ ] Rate limiting: enforced at 100 req/min per IP, tested
- [ ] Observability: traces exported to Jaeger, metrics to Prometheus
- [ ] Containerization: Docker builds <200 MB, K8s deploys with 0 downtime

### Frontend (M3)

- [ ] Phase 1 limitations clearly documented in-app
- [ ] Offline mode: last 10 results cached, accessible without backend
- [ ] Batch UI: encode/verify 10+ files in <5 seconds
- [ ] No new crashes or regressions in CI/CD

---

## Timeline Estimate

| Milestone | Tasks | Estimated Duration | Start | End |
|-----------|-------|-------------------|-------|-----|
| **M1: Decoder** | Heuristic redesign OR CNN training | 2–3 weeks | Week 1 | Week 3–4 |
| **M2: Hardening** | Redis, storage, rate limiting, observability, K8s | 3–4 weeks | Week 2 (parallel) | Week 5–6 |
| **M3: Frontend** | Decoder UI, offline, batch | 2–3 weeks | Week 4 | Week 6–7 |
| **Testing & Release** | Full integration tests, performance tuning, release prep | 1–2 weeks | Week 7 | Week 8–9 |

**Total: 8–9 weeks to Production v2.0**

---

## Decision Gates & Checkpoints

### Checkpoint 1 (Week 1)
- [ ] Heuristic decoder option analyzed; decision made (heuristic vs CNN)
- [ ] Redis spike completed; job store design approved
- [ ] Team aligned on Phase 2 scope

### Checkpoint 2 (Week 3)
- [ ] Decoder option (chosen path) achieves >85% accuracy on test set
  - **If <85%:** Switch to alternative approach (heuristic ↔ CNN)
- [ ] Redis job store integrated; tests passing
- [ ] Persistent storage (S3/GCS) spike complete

### Checkpoint 3 (Week 6)
- [ ] Decoder achieves >95% accuracy; ready for production
- [ ] Multi-worker deployment tested with 4+ workers
- [ ] Rate limiting, auth, observability integrated
- [ ] K8s manifests drafted

### Final Release (Week 9)
- [ ] Full integration tests passing on dev, staging, prod environments
- [ ] Load test: 50+ req/sec sustained
- [ ] Documentation updated (README, API, deployment guides)
- [ ] Release notes prepared

---

## Open Questions & Risks

### Decoder

- **Q:** Will CNN generalize to unseen audio types (music, speech, ambient noise)?
- **A (Phase 2):** Train on diverse dataset; use domain randomization

- **Q:** Can classical heuristic achieve >90% without ML?
- **A (Phase 2):** Decision gate at week 3

### Production

- **Q:** Should Redis be managed (e.g., AWS ElastiCache) or self-hosted?
- **A:** AWS ElastiCache for production; self-hosted for dev

- **Q:** File storage: Cloud (S3/GCS) vs. self-hosted (NFS, EBS)?
- **A:** Cloud for scalability; NFS as fallback

### Frontend

- **Q:** Can batch operations run on-device (local decode)?
- **A (Future):** Requires Dart STFT library; out of scope for Phase 2

---

## References

- **Classical Decoder Analysis:** See `backend/core/message_codec.py` (current z-score implementation)
- **Barker-13 Sync:** See `backend/core/sync.py` for correlation logic
- **Watermark Embedding:** See `backend/core/watermarker.py` for multi-resolution STFT

---

## Approval & Sign-Off

- [ ] Technical Lead Approval
- [ ] Product Lead Approval
- [ ] Security Review Approval
- [ ] Capacity Planning Approval

---

**Phase 2 Status:** ⏳ Planned  
**Last Updated:** 2025-04-25  
**Next Review:** Weekly sync (Mondays, 10 AM UTC)
