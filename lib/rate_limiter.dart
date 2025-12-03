import 'dart:collection';

/// Rate limiter to prevent API abuse
class RateLimiter {
  final HashMap<String, List<DateTime>> _requests = HashMap();
  final int maxRequests;
  final Duration window;
  DateTime _lastCleanup = DateTime.now();

  RateLimiter({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
  });

  /// Check if request is allowed for this identifier
  bool checkLimit(String identifier) {
    final now = DateTime.now();
    
    // Periodic cleanup every 5 minutes
    if (now.difference(_lastCleanup).inMinutes >= 5) {
      _cleanup();
    }
    
    final requests = _requests[identifier] ?? [];
    
    // Remove old requests outside time window
    requests.removeWhere((time) => now.difference(time) > window);
    
    if (requests.length >= maxRequests) {
      return false; // Rate limit exceeded
    }
    
    requests.add(now);
    _requests[identifier] = requests;
    return true;
  }

  /// Clean up old entries to prevent memory leak
  void _cleanup() {
    final now = DateTime.now();
    _requests.removeWhere((_, requests) => 
      requests.isEmpty || now.difference(requests.last) > window);
    _lastCleanup = now;
    print('🧹 Rate limiter cleanup: ${_requests.length} active IPs');
  }

  /// Get current request count for identifier
  int getRequestCount(String identifier) {
    final now = DateTime.now();
    final requests = _requests[identifier] ?? [];
    requests.removeWhere((time) => now.difference(time) > window);
    return requests.length;
  }
}
