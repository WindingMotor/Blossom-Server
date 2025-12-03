import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Standardized API response helpers
class ApiResponse {
  /// Success response
  static Response success(dynamic data, {int status = 200, String? message}) {
    final body = {
      'success': true,
      'data': data,
    };
    
    if (message != null) {
      body['message'] = message;
    }
    
    return Response(
      status,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
      },
      body: jsonEncode(body),
    );
  }

  /// Error response
  static Response error(String message, {int status = 400, String? details}) {
    final body = {
      'success': false,
      'error': message,
    };
    
    if (details != null) {
      body['details'] = details;
    }
    
    return Response(
      status,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
      },
      body: jsonEncode(body),
    );
  }

  /// Rate limit exceeded response
  static Response rateLimitExceeded({int retryAfter = 60}) {
    return Response(
      429,
      headers: {
        'Content-Type': 'application/json',
        'Retry-After': retryAfter.toString(),
        'Cache-Control': 'no-cache',
      },
      body: jsonEncode({
        'success': false,
        'error': 'Rate limit exceeded. Please try again later.',
        'retryAfter': retryAfter,
      }),
    );
  }

  /// Not found response
  static Response notFound(String message) {
    return error(message, status: 404);
  }

  /// Validation error response
  static Response validationError(String field, String message) {
    return error(
      'Validation failed',
      status: 422,
      details: '$field: $message',
    );
  }
}
