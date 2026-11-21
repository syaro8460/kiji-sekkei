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
