import 'dart:convert';

/// Reads the `sub` claim from a JWT access token without verifying the signature.
String? userIdFromAccessToken(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(payload);
    if (map is! Map<String, dynamic>) return null;
    final sub = map['sub'];
    if (sub is String && sub.isNotEmpty) return sub;
    return null;
  } catch (_) {
    return null;
  }
}
