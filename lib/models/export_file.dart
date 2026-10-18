import 'dart:convert';

enum ExportType {
  jsonBackup('backup', 'application/json'),
  tasksCsv('tasks', 'text/csv'),
  sleepCsv('sleep', 'text/csv'),
  savingsCsv('savings', 'text/csv'),
  activityCsv('activity', 'text/csv');

  const ExportType(this.dataset, this.mimeType);

  final String dataset;
  final String mimeType;
}

class ExportFile {
  final ExportType type;
  final String fileName;
  final String content;
  final String mimeType;
  final int recordCount;

  const ExportFile({
    required this.type,
    required this.fileName,
    required this.content,
    required this.mimeType,
    required this.recordCount,
  });

  int get byteLength => utf8.encode(content).length;
}
