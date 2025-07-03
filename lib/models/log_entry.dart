class LogEntry {
  final DateTime timestamp;
  final String method;
  final String url;
  final int statusCode;
  final String? userAgent;
  final String? remoteAddress;
  final Duration? responseTime;

  LogEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    required this.statusCode,
    this.userAgent,
    this.remoteAddress,
    this.responseTime,
  });

  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';

  String get statusColor {
    if (statusCode >= 200 && statusCode < 300) return 'success';
    if (statusCode >= 400 && statusCode < 500) return 'warning';
    if (statusCode >= 500) return 'error';
    return 'info';
  }

  String get methodColor {
    switch (method.toUpperCase()) {
      case 'GET':
        return 'blue';
      case 'POST':
        return 'green';
      case 'PUT':
        return 'orange';
      case 'DELETE':
        return 'red';
      default:
        return 'grey';
    }
  }

  String get shortUrl {
    if (url.length <= 30) return url;
    return '${url.substring(0, 25)}...';
  }

  String get responseTimeText {
    if (responseTime == null) return '';
    final ms = responseTime!.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'url': url,
        'status_code': statusCode,
        'user_agent': userAgent,
        'remote_address': remoteAddress,
        'response_time_ms': responseTime?.inMilliseconds,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.parse(json['timestamp']),
        method: json['method'],
        url: json['url'],
        statusCode: json['status_code'],
        userAgent: json['user_agent'],
        remoteAddress: json['remote_address'],
        responseTime: json['response_time_ms'] != null
            ? Duration(milliseconds: json['response_time_ms'])
            : null,
      );

  @override
  String toString() =>
      '[$formattedTime] $method $url - $statusCode $responseTimeText';
}
