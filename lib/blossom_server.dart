
import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'models.dart';

class BlossomServer {
  final Map<String, UserStatus> _users = {};
  Timer? _cleanupTimer;

  BlossomServer() {
    _startCleanup();
  }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      final now = DateTime.now();
      _users.removeWhere((uuid, user) => 
        !user.isOnline && now.difference(user.lastSeen).inMinutes > 30);
    });
  }

  Router get router {
    final router = Router();

    // Update user status (song change / heartbeat)
    router.post('/user/update', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        
        final uuid = data['uuid'] as String?;
        final username = data['username'] as String?;
        final currentSong = data['currentSong'] as String?;
        final currentArtist = data['currentArtist'] as String?;

        if (uuid == null || uuid.isEmpty) {
          return Response(400, body: 'UUID required');
        }

        final user = _users[uuid] ?? 
            UserStatus(uuid: uuid, username: username ?? 'Unknown');
        
        user.username = username ?? user.username;
        user.currentSong = currentSong;
        user.currentArtist = currentArtist;
        user.lastSeen = DateTime.now();
        user.isOnline = true;

        _users[uuid] = user;
        
        return Response.ok(jsonEncode(user.toJson()));
      } catch (e) {
        return Response(400, body: 'Invalid JSON');
      }
    });

    // Get user status
    router.get('/user/<uuid>', (Request request, String uuid) {
      final user = _users[uuid];
      if (user == null) {
        return Response.notFound('User $uuid not found');
      }
      return Response.ok(jsonEncode(user.toJson()));
    });

    // Heartbeat (just update online status)
    router.post('/user/heartbeat', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        
        final uuid = data['uuid'] as String?;
        if (uuid == null || uuid.isEmpty) {
          return Response(400, body: 'UUID required');
        }

        final user = _users[uuid];
        if (user != null) {
          user.lastSeen = DateTime.now();
          user.isOnline = true;
          _users[uuid] = user;
        }
        
        return Response.ok('OK');
      } catch (e) {
        return Response(400, body: 'Invalid JSON');
      }
    });

    // Health check
    router.get('/health', (Request request) => Response.ok('OK'));

    return router;
  }

  void close() {
    _cleanupTimer?.cancel();
  }
}
