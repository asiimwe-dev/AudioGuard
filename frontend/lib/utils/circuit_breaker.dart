/// Circuit Breaker Pattern Implementation
/// 
/// Prevents request storms by tracking failures and temporarily stopping requests
/// to allow backend recovery time.

import 'package:flutter/foundation.dart';

enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreakerConfig {
  final int failureThreshold; // Failures before opening circuit
  final Duration timeout; // How long to keep circuit open
  final int halfOpenAttempts; // Attempts allowed in half-open state

  const CircuitBreakerConfig({
    this.failureThreshold = 3,
    this.timeout = const Duration(seconds: 10),
    this.halfOpenAttempts = 2,
  });
}

class CircuitBreaker {
  final String name;
  final CircuitBreakerConfig config;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  int _halfOpenAttempts = 0;

  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;

  CircuitBreaker({
    required this.name,
    CircuitBreakerConfig? config,
  }) : config = config ?? const CircuitBreakerConfig();

  /// Check if request is allowed
  bool canAttempt() {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        // Check if timeout has elapsed
        if (_lastFailureTime != null) {
          final elapsed = DateTime.now().difference(_lastFailureTime!);
          if (elapsed >= config.timeout) {
            _transitionToHalfOpen();
            return true;
          }
        }
        return false;

      case CircuitBreakerState.halfOpen:
        return _halfOpenAttempts < config.halfOpenAttempts;
    }
  }

  /// Record a successful request
  void recordSuccess() {
    _failureCount = 0;
    _halfOpenAttempts = 0;
    if (_state != CircuitBreakerState.closed) {
      _state = CircuitBreakerState.closed;
      debugPrint('[CircuitBreaker] $name: Closed (success)');
    }
  }

  /// Record a failed request
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    switch (_state) {
      case CircuitBreakerState.closed:
        if (_failureCount >= config.failureThreshold) {
          _transitionToOpen();
        }
        break;

      case CircuitBreakerState.halfOpen:
        _halfOpenAttempts++;
        if (_halfOpenAttempts >= config.halfOpenAttempts) {
          _transitionToOpen();
        }
        break;

      case CircuitBreakerState.open:
        // Already open, just update timestamp
        break;
    }
  }

  void _transitionToOpen() {
    _state = CircuitBreakerState.open;
    _halfOpenAttempts = 0;
    debugPrint('[CircuitBreaker] $name: OPEN (failures: $_failureCount)');
  }

  void _transitionToHalfOpen() {
    _state = CircuitBreakerState.halfOpen;
    _halfOpenAttempts = 0;
    debugPrint('[CircuitBreaker] $name: Half-Open (retry after timeout)');
  }

  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _halfOpenAttempts = 0;
    _lastFailureTime = null;
  }

  @override
  String toString() => 'CircuitBreaker($name, state=$_state, failures=$_failureCount)';
}
