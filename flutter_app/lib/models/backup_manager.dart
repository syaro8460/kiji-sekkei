import 'dart:convert';
import 'dart:typed_data';

import 'backup_data.dart';

class BackupManager {
  static const supportedSchemaVersion = 1;

  Uint8List encode(BackupData backupData) {
    final encoder = JsonEncoder.withIndent('  ');
    final sortedJson = _sortJsonKeys(backupData.toJson());
    return Uint8List.fromList(utf8.encode(encoder.convert(sortedJson)));
  }

  BackupData decode(List<int> data) {
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup data must be a JSON object.');
    }

    final backupData = BackupData.fromJson(decoded);
    if (backupData.schemaVersion != supportedSchemaVersion) {
      throw FormatException(
        'Unsupported backup schema version: ${backupData.schemaVersion}',
      );
    }
    return backupData;
  }
}

Object? _sortJsonKeys(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _sortJsonKeys(value[key]),
    };
  }
  if (value is List) {
    return value.map(_sortJsonKeys).toList();
  }
  return value;
}
