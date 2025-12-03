import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../lib/blossom_server.dart';
import '../lib/request_logger.dart';

void main(List<String> args) async {
  // Create server instance
  final server = BlossomServer();
  
  // Setup middleware pipeline
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(_loggingMiddleware())
      .addHandler(server.router.call);

  // Get port from environment (Railway sets this automatically)
  final port = int.fromEnvironment('PORT', defaultValue: 8080);
  
  // Start server
  final httpServer = await serve(handler, InternetAddress.anyIPv4, port);
  
  // Log server start
  RequestLogger.logServerStart(httpServer.address.host, httpServer.port);
  
  // Graceful shutdown
  ProcessSignal.sigterm.watch().listen((_) async {
    print('🛑 Shutting down server...');
    await httpServer.close();
    server.close();
    exit(0);
  });
}

/// Logging middleware
Middleware _loggingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      
      try {
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);
        
        // Log successful request
        final method = request.method;
        final path = request.url.path;
        RequestLogger.logResponse(method, '/$path', response.statusCode, duration: duration);
        
        return response;
      } catch (e, stackTrace) {
        // Log error
        RequestLogger.logError(request.method, '/${request.url.path}', e, stackTrace: stackTrace);
        
        return Response.internalServerError(
          body: 'Internal server error',
        );
      }
    };
  };
}
