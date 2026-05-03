#!/usr/bin/env python3
"""
AudioGuard Backend Scalability Test Suite

Tests API stability, performance, and resource usage under various loads.
"""

import requests
import json
import time
import tempfile
import numpy as np
import soundfile as sf
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import List, Dict, Tuple

# Configuration
API_BASE_URL = "https://audioguard-api.onrender.com"
# API_BASE_URL = "http://localhost:8000"  # For local testing

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class TestResult:
    def __init__(self, test_name: str):
        self.test_name = test_name
        self.passed = False
        self.message = ""
        self.metrics = {}
        self.duration_ms = 0
        self.error = None

    def to_dict(self):
        return {
            "test": self.test_name,
            "passed": self.passed,
            "message": self.message,
            "metrics": self.metrics,
            "duration_ms": self.duration_ms,
            "error": str(self.error) if self.error else None,
        }


def create_test_audio(duration: float = 3.0, sample_rate: int = 44100, format_name: str = "wav") -> Tuple[str, float]:
    """Create a test audio file with specified duration and format."""
    t = np.linspace(0, duration, int(sample_rate * duration))
    # Create a simple sine wave (440 Hz)
    audio = 0.3 * np.sin(2 * np.pi * 440 * t).astype(np.float32)
    
    temp_file = tempfile.NamedTemporaryFile(suffix=f".{format_name}", delete=False)
    sf.write(temp_file.name, audio, sample_rate)
    
    return temp_file.name, duration


def test_health_check() -> TestResult:
    """Test 1: Basic health check"""
    result = TestResult("health_check")
    start = time.time()
    
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        result.metrics["status_code"] = response.status_code
        result.metrics["response_time_ms"] = (time.time() - start) * 1000
        
        if response.status_code == 200:
            data = response.json()
            result.passed = True
            result.message = f"✅ Health check passed - Status: {data.get('status', 'unknown')}"
            result.metrics["uptime_seconds"] = data.get("uptime_seconds", 0)
        else:
            result.message = f"❌ Health check failed - Status: {response.status_code}"
    except Exception as e:
        result.error = e
        result.message = f"❌ Health check error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_encode_single_file(file_path: str, message: str = "TEST_MESSAGE_001") -> TestResult:
    """Test 2: Single file encoding"""
    result = TestResult(f"encode_single_{Path(file_path).suffix}")
    start = time.time()
    
    try:
        with open(file_path, 'rb') as f:
            files = {'audio_file': f}
            data = {'message': message}
            response = requests.post(
                f"{API_BASE_URL}/api/v1/encode",
                files=files,
                data=data,
                timeout=60
            )
        
        result.metrics["status_code"] = response.status_code
        result.metrics["response_time_ms"] = (time.time() - start) * 1000
        
        if response.status_code == 200:
            resp_data = response.json()
            result.passed = True
            result.file_id = resp_data.get('file_id')
            result.message = f"✅ Encode succeeded - File ID: {result.file_id}"
            result.metrics.update({
                "processing_time_ms": resp_data.get('processing_time_ms'),
                "embedding_strength": resp_data.get('embedding_strength'),
            })
        else:
            result.message = f"❌ Encode failed - Status: {response.status_code}"
            result.metrics["error"] = response.text[:200]
    except Exception as e:
        result.error = e
        result.message = f"❌ Encode error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_decode_watermark(file_id: str) -> TestResult:
    """Test 3: Watermark decoding"""
    result = TestResult("decode_watermark")
    start = time.time()
    
    try:
        data = {
            'file_id': file_id,
            'use_cnn': False,
            'confidence_threshold': 0.5,
            'max_message_length': 256
        }
        response = requests.post(
            f"{API_BASE_URL}/api/v1/decode",
            json=data,
            timeout=30
        )
        
        result.metrics["status_code"] = response.status_code
        result.metrics["response_time_ms"] = (time.time() - start) * 1000
        
        if response.status_code == 200:
            resp_data = response.json()
            if resp_data.get('success'):
                result.passed = True
                result.message = f"✅ Decode succeeded - Message: {resp_data.get('message')}"
                result.metrics.update({
                    "confidence": resp_data.get('confidence'),
                    "processing_time_ms": resp_data.get('processing_time_ms'),
                })
            else:
                result.message = f"❌ Decode failed - {resp_data.get('error')}"
        else:
            result.message = f"❌ Decode failed - Status: {response.status_code}"
    except Exception as e:
        result.error = e
        result.message = f"❌ Decode error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_verify_watermark(file_id: str, message: str = "TEST_MESSAGE_001") -> TestResult:
    """Test 4: Watermark verification"""
    result = TestResult("verify_watermark")
    start = time.time()
    
    try:
        data = {
            'file_id': file_id,
            'expected_message': message,
            'confidence_threshold': 0.7
        }
        response = requests.post(
            f"{API_BASE_URL}/api/v1/verify",
            json=data,
            timeout=30
        )
        
        result.metrics["status_code"] = response.status_code
        result.metrics["response_time_ms"] = (time.time() - start) * 1000
        
        if response.status_code == 200:
            resp_data = response.json()
            if resp_data.get('success'):
                result.passed = True
                result.message = f"✅ Verify succeeded - Detected: {resp_data.get('watermark_detected')}"
                result.metrics.update({
                    "watermark_detected": resp_data.get('watermark_detected'),
                    "confidence": resp_data.get('confidence'),
                    "processing_time_ms": resp_data.get('processing_time_ms'),
                })
            else:
                result.message = f"❌ Verify failed"
        else:
            result.message = f"❌ Verify failed - Status: {response.status_code}"
    except Exception as e:
        result.error = e
        result.message = f"❌ Verify error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_analyze_audio(file_id: str) -> TestResult:
    """Test 5: Audio analysis"""
    result = TestResult("analyze_audio")
    start = time.time()
    
    try:
        data = {
            'file_id': file_id,
            'confidence_threshold': 0.5,
            'max_message_length': 256
        }
        response = requests.post(
            f"{API_BASE_URL}/api/v1/analyze",
            json=data,
            timeout=30
        )
        
        result.metrics["status_code"] = response.status_code
        result.metrics["response_time_ms"] = (time.time() - start) * 1000
        
        if response.status_code == 200:
            resp_data = response.json()
            if resp_data.get('success'):
                result.passed = True
                result.message = f"✅ Analyze succeeded - Watermark present: {resp_data.get('watermark_present')}"
                result.metrics.update({
                    "watermark_present": resp_data.get('watermark_present'),
                    "signal_strength": resp_data.get('signal_strength'),
                    "processing_time_ms": resp_data.get('processing_time_ms'),
                })
            else:
                result.message = f"❌ Analyze failed"
        else:
            result.message = f"❌ Analyze failed - Status: {response.status_code}"
    except Exception as e:
        result.error = e
        result.message = f"❌ Analyze error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_full_workflow(file_size_mb: float = 2.0, audio_format: str = "wav") -> TestResult:
    """Test 6: Full encode->decode->verify->analyze workflow"""
    result = TestResult(f"full_workflow_{file_size_mb}mb_{audio_format}")
    start = time.time()
    
    try:
        # Create test file
        duration = (file_size_mb * 1024 * 1024) / (44100 * 2)  # Rough estimate
        audio_file, _ = create_test_audio(duration=duration, format_name=audio_format)
        message = "SCALABILITY_TEST_WORKFLOW"
        
        # Step 1: Encode
        with open(audio_file, 'rb') as f:
            files = {'audio_file': f}
            data = {'message': message}
            response = requests.post(
                f"{API_BASE_URL}/api/v1/encode",
                files=files,
                data=data,
                timeout=120
            )
        
        if response.status_code != 200:
            result.message = f"❌ Workflow failed at encode - Status: {response.status_code}"
            return result
        
        file_id = response.json().get('file_id')
        encode_time = response.json().get('processing_time_ms')
        
        # Step 2: Decode
        response = requests.post(
            f"{API_BASE_URL}/api/v1/decode",
            json={'file_id': file_id, 'use_cnn': False},
            timeout=60
        )
        
        if response.status_code != 200 or not response.json().get('success'):
            result.message = f"❌ Workflow failed at decode"
            return result
        
        decode_time = response.json().get('processing_time_ms')
        decoded_msg = response.json().get('message')
        
        # Step 3: Verify
        response = requests.post(
            f"{API_BASE_URL}/api/v1/verify",
            json={'file_id': file_id, 'expected_message': message},
            timeout=60
        )
        
        if response.status_code != 200 or not response.json().get('success'):
            result.message = f"❌ Workflow failed at verify"
            return result
        
        verify_time = response.json().get('processing_time_ms')
        
        # Step 4: Analyze
        response = requests.post(
            f"{API_BASE_URL}/api/v1/analyze",
            json={'file_id': file_id},
            timeout=60
        )
        
        if response.status_code != 200 or not response.json().get('success'):
            result.message = f"❌ Workflow failed at analyze"
            return result
        
        analyze_time = response.json().get('processing_time_ms')
        
        result.passed = True
        result.message = f"✅ Full workflow succeeded ({audio_format}, {file_size_mb}MB)"
        result.metrics = {
            "encode_time_ms": encode_time,
            "decode_time_ms": decode_time,
            "verify_time_ms": verify_time,
            "analyze_time_ms": analyze_time,
            "total_time_ms": (time.time() - start) * 1000,
            "decoded_message": decoded_msg,
        }
        
        # Cleanup
        Path(audio_file).unlink(missing_ok=True)
        
    except Exception as e:
        result.error = e
        result.message = f"❌ Workflow error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def test_concurrent_operations(num_concurrent: int = 3) -> TestResult:
    """Test 7: Concurrent encoding operations"""
    result = TestResult(f"concurrent_encode_{num_concurrent}")
    start = time.time()
    
    try:
        def encode_task(task_id):
            audio_file, _ = create_test_audio()
            with open(audio_file, 'rb') as f:
                files = {'audio_file': f}
                data = {'message': f'CONCURRENT_TEST_{task_id}'}
                response = requests.post(
                    f"{API_BASE_URL}/api/v1/encode",
                    files=files,
                    data=data,
                    timeout=120
                )
            Path(audio_file).unlink(missing_ok=True)
            return response.status_code == 200
        
        # Run concurrent operations
        with ThreadPoolExecutor(max_workers=num_concurrent) as executor:
            futures = [executor.submit(encode_task, i) for i in range(num_concurrent)]
            results = [f.result() for f in as_completed(futures)]
        
        passed_count = sum(results)
        result.passed = passed_count == num_concurrent
        result.message = f"✅ Concurrent test: {passed_count}/{num_concurrent} succeeded" if result.passed else f"❌ Concurrent test: {passed_count}/{num_concurrent} succeeded"
        result.metrics = {
            "total_requests": num_concurrent,
            "successful": passed_count,
            "failed": num_concurrent - passed_count,
        }
        
    except Exception as e:
        result.error = e
        result.message = f"❌ Concurrent test error: {str(e)}"
    
    result.duration_ms = (time.time() - start) * 1000
    return result


def main():
    """Run all scalability tests"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*80}")
    print(f"AudioGuard Backend Scalability Test Suite")
    print(f"{'='*80}{Colors.ENDC}\n")
    
    print(f"API Base URL: {API_BASE_URL}")
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    results: List[TestResult] = []
    
    # Test Suite
    print(f"{Colors.OKBLUE}Running tests...{Colors.ENDC}\n")
    
    # 1. Health Check
    print("Test 1: Health Check")
    result = test_health_check()
    results.append(result)
    print(f"  {result.message}")
    print(f"  Duration: {result.duration_ms:.2f}ms\n")
    
    # 2-5. File Format Testing
    file_sizes = [2.0]  # MB - adjust based on your needs
    formats = ["wav"]  # Can add "mp3", "m4a", "ogg" if encoders available
    
    for fmt in formats:
        for size in file_sizes:
            print(f"Test: Single File Encode ({size}MB {fmt.upper()})")
            audio_file, duration = create_test_audio(duration=size*0.5, format_name=fmt)
            result = test_encode_single_file(audio_file, message="SCALABILITY_TEST")
            results.append(result)
            print(f"  {result.message}")
            print(f"  Duration: {result.duration_ms:.2f}ms\n")
            
            if result.passed:
                # Test decode
                print(f"  └─ Testing Decode")
                decode_result = test_decode_watermark(result.file_id)
                results.append(decode_result)
                print(f"     {decode_result.message}")
                print(f"     Duration: {decode_result.duration_ms:.2f}ms\n")
                
                # Test verify
                print(f"  └─ Testing Verify")
                verify_result = test_verify_watermark(result.file_id, "SCALABILITY_TEST")
                results.append(verify_result)
                print(f"     {verify_result.message}")
                print(f"     Duration: {verify_result.duration_ms:.2f}ms\n")
                
                # Test analyze
                print(f"  └─ Testing Analyze")
                analyze_result = test_analyze_audio(result.file_id)
                results.append(analyze_result)
                print(f"     {analyze_result.message}")
                print(f"     Duration: {analyze_result.duration_ms:.2f}ms\n")
            
            Path(audio_file).unlink(missing_ok=True)
    
    # 6. Full Workflow
    print("Test: Full Workflow (2MB WAV)")
    result = test_full_workflow(file_size_mb=2.0, audio_format="wav")
    results.append(result)
    print(f"  {result.message}")
    print(f"  Duration: {result.duration_ms:.2f}ms\n")
    
    # 7. Concurrent Operations
    print("Test: Concurrent Operations (3 simultaneous)")
    result = test_concurrent_operations(num_concurrent=3)
    results.append(result)
    print(f"  {result.message}")
    print(f"  Duration: {result.duration_ms:.2f}ms\n")
    
    # Summary Report
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*80}")
    print(f"Test Summary")
    print(f"{'='*80}{Colors.ENDC}\n")
    
    passed = sum(1 for r in results if r.passed)
    total = len(results)
    
    print(f"Total Tests: {total}")
    print(f"Passed: {Colors.OKGREEN}{passed}{Colors.ENDC}")
    print(f"Failed: {Colors.FAIL}{total - passed}{Colors.ENDC}")
    print(f"Success Rate: {(passed/total*100):.1f}%\n")
    
    # Detailed Results
    print(f"{Colors.BOLD}Detailed Results:{Colors.ENDC}")
    for result in results:
        status = f"{Colors.OKGREEN}✓{Colors.ENDC}" if result.passed else f"{Colors.FAIL}✗{Colors.ENDC}"
        print(f"\n{status} {result.test_name}")
        print(f"  Message: {result.message}")
        print(f"  Duration: {result.duration_ms:.2f}ms")
        if result.metrics:
            for key, value in result.metrics.items():
                if isinstance(value, float):
                    print(f"  {key}: {value:.2f}")
                else:
                    print(f"  {key}: {value}")
    
    # Save Results to JSON
    report = {
        "timestamp": datetime.now().isoformat(),
        "api_base_url": API_BASE_URL,
        "total_tests": total,
        "passed": passed,
        "failed": total - passed,
        "success_rate": passed / total * 100,
        "results": [r.to_dict() for r in results],
    }
    
    report_file = Path("scalability_test_report.json")
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n{Colors.OKBLUE}Report saved to: {report_file}{Colors.ENDC}\n")


if __name__ == "__main__":
    main()
