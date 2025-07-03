import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'api_server.dart';

class TrayService {
  static TrayService? _instance;
  static TrayService get instance => _instance ??= TrayService._();
  TrayService._();

  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize system tray
      await _systemTray.initSystemTray(
        title: "API Server",
        iconPath: _getTrayIconPath(),
      );

      await _setupTrayMenu();
      _initialized = true;
    } catch (e) {
      print('Failed to initialize system tray: $e');
    }
  }

  String _getTrayIconPath() {
    // Use a simple dot as icon for cross-platform compatibility
    if (Platform.isWindows) {
      return 'assets/icon.ico';
    } else if (Platform.isLinux) {
      return 'assets/icon.png';
    } else if (Platform.isMacOS) {
      return 'assets/icon.png';
    }
    return '';
  }

  Future<void> _setupTrayMenu() async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Abrir Interface',
        onClicked: (menuItem) => _showWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Status do Servidor',
        onClicked: (menuItem) => _showServerStatus(),
      ),
      MenuItemLabel(
        label: ApiServer.instance.isRunning
            ? 'Parar Servidor'
            : 'Iniciar Servidor',
        onClicked: (menuItem) => _toggleServer(),
      ),
      MenuItemLabel(
        label: 'Reiniciar Servidor',
        onClicked: (menuItem) => _restartServer(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Sair',
        onClicked: (menuItem) => _exitApplication(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  Future<void> updateServerStatus(bool isRunning) async {
    if (!_initialized) return;

    try {
      // Update tray tooltip
      await _systemTray.setToolTip(
          isRunning ? 'API Server - Rodando' : 'API Server - Parado');

      // Update menu
      await _setupTrayMenu();
    } catch (e) {
      print('Failed to update tray status: $e');
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      print('Failed to show window: $e');
    }
  }

  Future<void> _showServerStatus() async {
    final server = ApiServer.instance;
    String message;

    if (server.isRunning) {
      final uptime = server.uptime;
      final uptimeText = uptime != null
          ? '${uptime.inHours}h ${uptime.inMinutes % 60}m ${uptime.inSeconds % 60}s'
          : 'Desconhecido';

      message = '''Status: Rodando
URL: ${server.serverUrl}
Tempo ativo: $uptimeText
Iniciado em: ${server.startTime?.toString().split('.').first ?? 'Desconhecido'}''';
    } else {
      message = 'Status: Parado\nO servidor não está rodando.';
    }

    await _systemTray.popUpContextMenu();
  }

  Future<void> _toggleServer() async {
    final server = ApiServer.instance;

    if (server.isRunning) {
      await server.stop();
    } else {
      await server.start();
    }

    await updateServerStatus(server.isRunning);
  }

  Future<void> _restartServer() async {
    await ApiServer.instance.restart();
    await updateServerStatus(ApiServer.instance.isRunning);
  }

  Future<void> _exitApplication() async {
    await ApiServer.instance.stop();
    await windowManager.destroy();
    exit(0);
  }

  Future<void> hideToTray() async {
    try {
      await windowManager.hide();
    } catch (e) {
      print('Failed to hide to tray: $e');
    }
  }

  void dispose() {
    _systemTray.destroy();
  }
}
