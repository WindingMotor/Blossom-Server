import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'models.dart';
import 'rate_limiter.dart';
import 'validator.dart';
import 'api_response.dart';
import 'request_logger.dart';

class BlossomServer {
  final Map<String, UserStatus> _users = {};
  final RateLimiter _rateLimiter = RateLimiter(
    maxRequests: 60,
    window: Duration(minutes: 1),
  );
  
  Timer? _cleanupTimer;
  Timer? _statsTimer;

  BlossomServer() {
    _startCleanup();
    _startStatsLogging();
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      final now = DateTime.now();
      final initialCount = _users.length;
      
      // Remove users offline for more than 30 minutes
      _users.removeWhere((uuid, user) => 
        !user.isOnline && now.difference(user.lastSeen).inMinutes > 30);
      
      final removed = initialCount - _users.length;
      if (removed > 0) {
        print('🧹 Cleanup: Removed $removed inactive users');
      }
    });
  }

  void _startStatsLogging() {
    _statsTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      final onlineCount = _users.values.where((u) => u.isOnline).length;
      RequestLogger.logPeriodicStats(_users.length, onlineCount);
    });
  }

  /// Get client IP from request
  String _getClientIp(Request request) {
    return request.headers['x-forwarded-for'] ?? 
           request.headers['x-real-ip'] ?? 
           request.headers['host'] ?? 
           'unknown';
  }

  Router get router {
    final router = Router();

    // Update user status (song change / heartbeat)
    router.post('/user/update', (Request request) async {
      final startTime = DateTime.now();
      final ip = _getClientIp(request);
      
      // Rate limiting
      if (!_rateLimiter.checkLimit(ip)) {
        RequestLogger.logResponse('POST', '/user/update', 429, duration: DateTime.now().difference(startTime));
        return ApiResponse.rateLimitExceeded();
      }

      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        
        // Validate UUID
        final uuid = data['uuid'] as String?;
        if (!Validator.isValidUuid(uuid)) {
          RequestLogger.logResponse('POST', '/user/update', 422, duration: DateTime.now().difference(startTime));
          return ApiResponse.validationError('uuid', 'Invalid UUID format');
        }

        // Sanitize inputs
        final username = Validator.sanitizeString(data['username'], maxLength: 50) ?? 'Music Lover';
        final currentSong = Validator.sanitizeString(data['currentSong'], maxLength: 200);
        final currentArtist = Validator.sanitizeString(data['currentArtist'], maxLength: 100);
        final albumArt = data['albumArt'] as String?;

        // Validate album art if provided
        if (albumArt != null && albumArt.isNotEmpty && !Validator.isValidBase64(albumArt)) {
          RequestLogger.logResponse('POST', '/user/update', 422, uuid: uuid, duration: DateTime.now().difference(startTime));
          return ApiResponse.validationError('albumArt', 'Invalid base64 format or size too large');
        }

        // Update or create user
        final user = _users[uuid!] ?? UserStatus(uuid: uuid, username: username);
        
        user.username = username;
        user.currentSong = currentSong;
        user.currentArtist = currentArtist;
        
        if (albumArt != null && albumArt.isNotEmpty) {
          user.albumArt = albumArt;
        }
        
        user.lastSeen = DateTime.now();
        user.isOnline = true;

        _users[uuid] = user;
        
        RequestLogger.logResponse('POST', '/user/update', 200, uuid: uuid, duration: DateTime.now().difference(startTime));
        return ApiResponse.success(user.toJson(), message: 'Status updated successfully');
        
      } catch (e, stackTrace) {
        RequestLogger.logError('POST', '/user/update', e, stackTrace: stackTrace);
        return ApiResponse.error('Invalid request format', status: 400);
      }
    });

    // Get user status
    router.get('/user/<uuid>', (Request request, String uuid) {
      final startTime = DateTime.now();
      final ip = _getClientIp(request);
      
      // Rate limiting
      if (!_rateLimiter.checkLimit(ip)) {
        RequestLogger.logResponse('GET', '/user/$uuid', 429, duration: DateTime.now().difference(startTime));
        return ApiResponse.rateLimitExceeded();
      }

      if (!Validator.isValidUuid(uuid)) {
        RequestLogger.logResponse('GET', '/user/$uuid', 422, duration: DateTime.now().difference(startTime));
        return ApiResponse.validationError('uuid', 'Invalid UUID format');
      }

      final user = _users[uuid];
      if (user == null) {
        RequestLogger.logResponse('GET', '/user/$uuid', 404, duration: DateTime.now().difference(startTime));
        return ApiResponse.notFound('User not found');
      }
      
      // Update online status based on last seen
      final now = DateTime.now();
      if (now.difference(user.lastSeen).inMinutes > 2) {
        user.isOnline = false;
      }
      
      RequestLogger.logResponse('GET', '/user/$uuid', 200, uuid: uuid, duration: DateTime.now().difference(startTime));
      return ApiResponse.success(user.toJson());
    });

    // Batch get multiple users (efficiency!)
    router.post('/users/batch', (Request request) async {
      final startTime = DateTime.now();
      final ip = _getClientIp(request);
      
      // Rate limiting
      if (!_rateLimiter.checkLimit(ip)) {
        RequestLogger.logResponse('POST', '/users/batch', 429, duration: DateTime.now().difference(startTime));
        return ApiResponse.rateLimitExceeded();
      }

      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        final uuids = (data['uuids'] as List<dynamic>).cast<String>();
        
        // Limit batch size
        if (uuids.length > 50) {
          return ApiResponse.validationError('uuids', 'Maximum 50 users per batch request');
        }
        
        final now = DateTime.now();
        final results = <String, dynamic>{};
        
        for (final uuid in uuids) {
          if (!Validator.isValidUuid(uuid)) continue;
          
          final user = _users[uuid];
          if (user != null) {
            // Update online status
            if (now.difference(user.lastSeen).inMinutes > 2) {
              user.isOnline = false;
            }
            results[uuid] = user.toJson();
          }
        }
        
        RequestLogger.logResponse('POST', '/users/batch', 200, duration: DateTime.now().difference(startTime));
        return ApiResponse.success(results, message: 'Fetched ${results.length} users');
        
      } catch (e, stackTrace) {
        RequestLogger.logError('POST', '/users/batch', e, stackTrace: stackTrace);
        return ApiResponse.error('Invalid request format', status: 400);
      }
    });

    // Friend discovery - search users by username
    router.get('/users/search', (Request request) {
      final startTime = DateTime.now();
      final ip = _getClientIp(request);
      
      // Rate limiting (stricter for search)
      if (_rateLimiter.getRequestCount(ip) > 30) {
        RequestLogger.logResponse('GET', '/users/search', 429, duration: DateTime.now().difference(startTime));
        return ApiResponse.rateLimitExceeded();
      }
      
      if (!_rateLimiter.checkLimit(ip)) {
        return ApiResponse.rateLimitExceeded();
      }

      final query = request.url.queryParameters['q'];
      
      if (!Validator.isValidSearchQuery(query)) {
        RequestLogger.logResponse('GET', '/users/search', 422, duration: DateTime.now().difference(startTime));
        return ApiResponse.validationError('q', 'Search query must be 2-50 characters (letters/numbers only)');
      }

      final searchTerm = query!.toLowerCase();
      final now = DateTime.now();
      
      // Search users by username
      final results = _users.values
          .where((user) {
            // Only show users active in last 7 days
            if (now.difference(user.lastSeen).inDays > 7) return false;
            return user.username.toLowerCase().contains(searchTerm);
          })
          .take(20) // Limit results
          .map((user) => {
            'uuid': user.uuid,
            'username': user.username,
            'isOnline': user.isOnline && now.difference(user.lastSeen).inMinutes <= 2,
            'lastSeen': user.lastSeen.toIso8601String(),
          })
          .toList();
      
      // Sort by online status first, then by username
      results.sort((a, b) {
        if (a['isOnline'] != b['isOnline']) {
          return (b['isOnline'] as bool) ? 1 : -1;
        }
        return (a['username'] as String).compareTo(b['username'] as String);
      });
      
      RequestLogger.logResponse('GET', '/users/search', 200, duration: DateTime.now().difference(startTime));
      return ApiResponse.success(results, message: 'Found ${results.length} users');
    });

    // Heartbeat (just update online status)
    router.post('/user/heartbeat', (Request request) async {
      final startTime = DateTime.now();
      final ip = _getClientIp(request);
      
      // Lighter rate limit for heartbeats
      if (_rateLimiter.getRequestCount(ip) > 100) {
        return ApiResponse.rateLimitExceeded();
      }

      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        
        final uuid = data['uuid'] as String?;
        if (!Validator.isValidUuid(uuid)) {
          return ApiResponse.validationError('uuid', 'Invalid UUID format');
        }

        final user = _users[uuid!];
        if (user != null) {
          user.lastSeen = DateTime.now();
          user.isOnline = true;
        }
        
        RequestLogger.logResponse('POST', '/user/heartbeat', 200, uuid: uuid, duration: DateTime.now().difference(startTime));
        return ApiResponse.success({'status': 'ok'});
        
      } catch (e) {
        return ApiResponse.error('Invalid request format', status: 400);
      }
    });

    // Health check
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    });

    // Stats endpoint
    router.get('/stats', (Request request) {
      final now = DateTime.now();
      final onlineUsers = _users.values.where((u) => 
        u.isOnline && now.difference(u.lastSeen).inMinutes <= 2).length;
      
      final stats = {
        'totalUsers': _users.length,
        'onlineUsers': onlineUsers,
        'serverTime': now.toIso8601String(),
        'requestStats': RequestLogger.getStats(),
      };
      
      return ApiResponse.success(stats);
    });

    return router;
  }

  void close() {
    _cleanupTimer?.cancel();
    _statsTimer?.cancel();
  }
}
