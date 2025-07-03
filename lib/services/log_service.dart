import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../models/log_entry.dart';

class LogService {
  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._();
  LogService._();

  final Queue<LogEntry> _logs = Queue<LogEntry>();
  final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();
  static const int maxLogs = 100;

  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logs => _logs.toList();
  int get logCount => _logs.length;

  void addLog(LogEntry log) {
    _logs.addFirst(log);

    // Keep only the latest 100 logs
    while (_logs.length > maxLogs) {
      _logs.removeLast();
    }

    _logController.add(log);
  }

  void addHttpLog({
    required String method,
    required String url,
    required int statusCode,
    String? userAgent,
    String? remoteAddress,
    Duration? responseTime,
  }) {
    final log = LogEntry(
      timestamp: DateTime.now(),
      method: method,
      url: url,
      statusCode: statusCode,
      userAgent: userAgent,
      remoteAddress: remoteAddress,
      responseTime: responseTime,
    );
    addLog(log);
  }

  void addSystemLog(String message, {String level = 'INFO'}) {
    final log = LogEntry(
      timestamp: DateTime.now(),
      method: 'SYSTEM',
      url: message,
      statusCode: level == 'ERROR' ? 500 : 200,
    );
    addLog(log);
  }

  void clearLogs() {
    _logs.clear();
  }

  List<LogEntry> getLogsByMethod(String method) => _logs
      .where((log) => log.method.toUpperCase() == method.toUpperCase())
      .toList();

  List<LogEntry> getLogsByStatusCode(int statusCode) =>
      _logs.where((log) => log.statusCode == statusCode).toList();

  List<LogEntry> getLogsByTimeRange(DateTime start, DateTime end) => _logs
      .where(
          (log) => log.timestamp.isAfter(start) && log.timestamp.isBefore(end))
      .toList();

  List<LogEntry> getRecentLogs(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _logs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  // Statistics
  Map<String, int> getMethodStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      stats[log.method] = (stats[log.method] ?? 0) + 1;
    }
    return stats;
  }

  Map<int, int> getStatusCodeStats() {
    final stats = <int, int>{};
    for (final log in _logs) {
      stats[log.statusCode] = (stats[log.statusCode] ?? 0) + 1;
    }
    return stats;
  }

  int get successfulRequests => _logs
      .where((log) => log.statusCode >= 200 && log.statusCode < 300)
      .length;

  int get errorRequests => _logs.where((log) => log.statusCode >= 400).length;

  double get averageResponseTime {
    final logsWithTime = _logs.where((log) => log.responseTime != null);
    if (logsWithTime.isEmpty) return 0.0;

    final totalMs = logsWithTime
        .map((log) => log.responseTime!.inMilliseconds)
        .reduce((a, b) => a + b);

    return totalMs / logsWithTime.length;
  }

  // Export logs
  Future<String> exportLogsAsText() async {
    final buffer = StringBuffer();
    buffer.writeln('API Server Logs - Exported at ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final log in logs.reversed) {
      buffer.writeln(log.toString());
    }

    buffer.writeln();
    buffer.writeln('Statistics:');
    buffer.writeln('Total Requests: ${_logs.length}');
    buffer.writeln('Successful: $successfulRequests');
    buffer.writeln('Errors: $errorRequests');
    buffer.writeln(
        'Average Response Time: ${averageResponseTime.toStringAsFixed(2)}ms');

    return buffer.toString();
  }

  Future<String> exportLogsAsJson() async {
    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'total_logs': _logs.length,
      'logs': _logs.map((log) => log.toJson()).toList(),
      'statistics': {
        'methods': getMethodStats(),
        'status_codes': getStatusCodeStats(),
        'successful_requests': successfulRequests,
        'error_requests': errorRequests,
        'average_response_time_ms': averageResponseTime,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> saveLogsToFile(String path, {bool asJson = false}) async {
    final content =
        asJson ? await exportLogsAsJson() : await exportLogsAsText();
    final file = File(path);
    await file.writeAsString(content);
  }

  void dispose() {
    _logController.close();
  }
}
