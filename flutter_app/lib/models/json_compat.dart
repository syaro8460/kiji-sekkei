import 'dart:math';

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final _iso8601Pattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);

String requireUuid(Object? value, String fieldName) {
  if (value is String && _uuidPattern.hasMatch(value)) {
    return value.toLowerCase();
  }
  throw FormatException('$fieldName must be a UUID.');
}

DateTime parseIso8601Date(Object? value, String fieldName) {
  if (value is String && _iso8601Pattern.hasMatch(value)) {
    return DateTime.parse(value);
  }
  throw FormatException('$fieldName must be an ISO-8601 date.');
}

String encodeIso8601Date(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  final second = utc.second.toString().padLeft(2, '0');

  return '$year-$month-${day}T$hour:$minute:${second}Z';
}

String newUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  // Set the version and variant bits for an RFC UUID v4.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}
