"""Decode benchmark for Phase 2 tuning.
Generates synthetic sine audio, encodes watermark with varying strengths and redundancy,
optionally adds Gaussian noise, and runs the Watermarker.decode to collect metrics.

Usage: python3 backend/tools/decode_benchmark.py
"""

import json
import tempfile
import os
import numpy as np
import soundfile as sf
from pathlib import Path

from backend.core.watermarker import Watermarker, WatermarkConfig


def make_sine(path, duration=3.0, sr=44100, freq=440.0, amp=0.3):
    t = np.linspace(0, duration, int(sr * duration), endpoint=False, dtype=np.float32)
    audio = amp * np.sin(2 * np.pi * freq * t)
    sf.write(str(path), audio, sr)
    return str(path)


def add_noise(src_path, dst_path, noise_std):
    audio, sr = sf.read(src_path, dtype='float32')
    noise = np.random.normal(0.0, noise_std, size=audio.shape).astype(np.float32)
    noisy = audio + noise
    sf.write(str(dst_path), noisy, sr)
    return str(dst_path)


def run_trial(amplitude, redundancy, noise_std):
    with tempfile.TemporaryDirectory() as td:
        in_path = Path(td) / 'in.wav'
        wm_out = Path(td) / 'wm.wav'
        noisy = Path(td) / 'noisy.wav'
        make_sine(in_path)
        cfg = WatermarkConfig(amplitude_factor=amplitude, redundancy=redundancy)
        wm = Watermarker(cfg)
        msg = f"TEST_A{amplitude}_R{redundancy}"
        enc = wm.encode(str(in_path), str(wm_out), msg)
        if not enc.success:
            return {'error': 'encode_failed', 'encode_error': enc.error}
        if noise_std > 0.0:
            target = add_noise(wm_out, noisy, noise_std)
        else:
            target = str(wm_out)
        dec = wm.decode(target)
        return {
            'amplitude': amplitude,
            'redundancy': redundancy,
            'noise_std': noise_std,
            'encode_snr_db': enc.snr_db,
            'encode_processing_ms': enc.processing_time_ms,
            'decode_success': dec.success,
            'decode_message': dec.message,
            'decode_confidence': dec.confidence,
            'decode_snr_db': dec.snr_db,
            'decode_ber': dec.ber_estimate,
            'decode_sync_found': dec.sync_found,
            'decode_ecc_errors': dec.ecc_errors,
            'decode_method': dec.method,
            'decode_processing_ms': dec.processing_time_ms,
        }


if __name__ == '__main__':
    amplitudes = [0.05, 0.08, 0.12, 0.15]
    redundancies = [1, 3]
    noises = [0.0, 0.005, 0.01, 0.02]

    results = []
    for amp in amplitudes:
        for red in redundancies:
            for n in noises:
                for trial in range(3):
                    r = run_trial(amp, red, n)
                    print(json.dumps(r))
                    results.append(r)

    # Summarize by amplitude/redundancy
    summary = {}
    for r in results:
        if 'error' in r:
            continue
        key = (r['amplitude'], r['redundancy'], r['noise_std'])
        summary.setdefault(key, {'trials': 0, 'successes': 0, 'conf_sum': 0.0})
        summary[key]['trials'] += 1
        summary[key]['successes'] += 1 if r['decode_success'] else 0
        summary[key]['conf_sum'] += float(r['decode_confidence'])

    print('\nSUMMARY:')
    for key, v in summary.items():
        amp, red, noise = key
        trials = v['trials']
        succ = v['successes']
        avg_conf = v['conf_sum'] / trials if trials else 0.0
        print(f"amp={amp} red={red} noise={noise} -> {succ}/{trials} success, avg_conf={avg_conf:.3f}")
