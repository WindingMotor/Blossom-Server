/// Request logging and monitoring utilities
class RequestLogger {
  static int _requestCount = 0;
  static DateTime _startTime = DateTime.now();

  /// Log incoming request
  static void logRequest(String method, String path, {String? uuid, String? ip}) {
    _requestCount++;
    final timestamp = DateTime.now().toIso8601String();
    final userInfo = uuid != null ? ' [user: $uuid]' : '';
    final ipInfo = ip != null ? ' [ip: $ip]' : '';
    
    print('📥 [$timestamp] $method $path$userInfo$ipInfo');
  }

  /// Log response
  static void logResponse(String method, String path, int statusCode, {String? uuid, Duration? duration}) {
    final timestamp = DateTime.now().toIso8601String();
    final userInfo = uuid != null ? ' [user: $uuid]' : '';
    final durationInfo = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    final emoji = statusCode < 300 ? '✅' : statusCode < 400 ? '📝' : '❌';
    
    print('$emoji [$timestamp] $method $path - $statusCode$userInfo$durationInfo');
  }

  /// Log error
  static void logError(String method, String path, dynamic error, {String? uuid, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final userInfo = uuid != null ? ' [user: $uuid]' : '';
    
    print('❌ [$timestamp] $method $path ERROR$userInfo: $error');
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }

  /// Get server statistics
  static Map<String, dynamic> getStats() {
    final uptime = DateTime.now().difference(_startTime);
    return {
      'totalRequests': _requestCount,
      'uptimeSeconds': uptime.inSeconds,
      'uptimeMinutes': uptime.inMinutes,
      'requestsPerMinute': uptime.inMinutes > 0 ? (_requestCount / uptime.inMinutes).toStringAsFixed(2) : '0',
    };
  }

  /// Log server start
  static void logServerStart(String host, int port) {
    print('🚀 ═══════════════════════════════════════════════════════');
    print('🎵 Blossom Music Server Started');
    print('📍 Address: http://$host:$port');
    print('⏰ Time: ${DateTime.now().toIso8601String()}');
    print('🚀 ═══════════════════════════════════════════════════════');
  }

  /// Log periodic stats
  static void logPeriodicStats(int userCount, int onlineCount) {
    print('📊 Stats: $userCount total users, $onlineCount online | ${_requestCount} requests total');
  }
}
