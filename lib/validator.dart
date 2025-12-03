import 'dart:convert';

/// Input validation and sanitization utilities
class Validator {
  /// Validate UUID format
  static bool isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return false;
    
    // Must start with 'user-' and be reasonable length
    if (!uuid.startsWith('user-')) return false;
    if (uuid.length < 15 || uuid.length > 50) return false;
    
    // Must only contain alphanumeric, hyphens
    final validPattern = RegExp(r'^user-[a-zA-Z0-9\-]+$');
    return validPattern.hasMatch(uuid);
  }

  /// Sanitize string input to prevent XSS/injection
  static String? sanitizeString(String? input, {int maxLength = 200}) {
    if (input == null || input.isEmpty) return null;
    
    // Remove potentially dangerous characters
    // Note: Using regular string with proper escaping instead of raw string
    String cleaned = input
        .replaceAll(RegExp('[<>"\'\\\\]'), '') // Remove <, >, ", ', \
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .trim();
    
    if (cleaned.isEmpty) return null;
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    
    return cleaned;
  }

  /// Validate base64 string (for album art)
  static bool isValidBase64(String? input) {
    if (input == null || input.isEmpty) return false;
    
    // Check reasonable size (max 200KB encoded)
    // Base64 encoding increases size by ~33%, so 200KB becomes ~266KB
    if (input.length > 266000) return false;
    
    try {
      final decoded = base64Decode(input);
      // Sanity check: decoded size should be reasonable (200KB)
      return decoded.length < 200000;
    } catch (e) {
      return false;
    }
  }

  /// Validate search query
  static bool isValidSearchQuery(String? query) {
    if (query == null || query.isEmpty) return false;
    if (query.length < 2 || query.length > 50) return false;
    
    // Allow letters, numbers, spaces, basic punctuation
    final validPattern = RegExp(r'^[a-zA-Z0-9\s]+$');
    return validPattern.hasMatch(query);
  }
}
