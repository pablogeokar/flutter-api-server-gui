import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance => _instance ??= ConfigService._();
  ConfigService._();

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Default values
  static const int defaultPort = 3000;
  static const String defaultDatabasePath = 'api_server.db';
  static const bool defaultAutoStart = true;
  static const bool defaultMinimizeToTray = true;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Server Port
  int get serverPort => _prefs.getInt('server_port') ?? defaultPort;
  Future<void> setServerPort(int port) async {
    if (port < 1024 || port > 65535) {
      throw ArgumentError('A porta precisa estar entre 1024 e 65535');
    }
    await _prefs.setInt('server_port', port);
  }

  // Database Path
  String get databasePath =>
      _prefs.getString('database_path') ?? defaultDatabasePath;
  Future<void> setDatabasePath(String path) async {
    if (path.trim().isEmpty) {
      throw ArgumentError('O caminho do banco de dados não pode estar vazio');
    }
    await _prefs.setString('database_path', path);
  }

  // Auto Start Server
  bool get autoStartServer =>
      _prefs.getBool('auto_start_server') ?? defaultAutoStart;
  Future<void> setAutoStartServer(bool autoStart) async {
    await _prefs.setBool('auto_start_server', autoStart);
  }

  // Minimize to Tray
  bool get minimizeToTray =>
      _prefs.getBool('minimize_to_tray') ?? defaultMinimizeToTray;
  Future<void> setMinimizeToTray(bool minimize) async {
    await _prefs.setBool('minimize_to_tray', minimize);
  }

  // Server Statistics
  int get totalRequests => _prefs.getInt('total_requests') ?? 0;
  Future<void> incrementRequests() async {
    await _prefs.setInt('total_requests', totalRequests + 1);
  }

  DateTime? get lastStartTime {
    final timestamp = _prefs.getInt('last_start_time');
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> setLastStartTime(DateTime time) async {
    await _prefs.setInt('last_start_time', time.millisecondsSinceEpoch);
  }

  // Reset all settings
  Future<void> resetToDefaults() async {
    await _prefs.clear();
  }

  // Export settings as JSON
  Map<String, dynamic> exportSettings() => {
        'server_port': serverPort,
        'database_path': databasePath,
        'auto_start_server': autoStartServer,
        'minimize_to_tray': minimizeToTray,
        'total_requests': totalRequests,
        'last_start_time': lastStartTime?.toIso8601String(),
      };

  // Validate port availability
  bool isValidPort(int port) => port >= 1024 && port <= 65535;

  // Get server URL
  String getServerUrl(String ipAddress) => 'http://$ipAddress:$serverPort';
}
