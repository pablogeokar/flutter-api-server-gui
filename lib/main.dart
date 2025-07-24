import 'package:flutter/material.dart';
import 'api_server_app.dart';
import 'package:window_manager/window_manager.dart';
import 'services/tray_service.dart';
import 'dart:io';

class AppWindowListener extends WindowListener {
  @override
  Future<void> onWindowClose() async {
    await TrayService.instance.hideToTray();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Servidor de API',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Initialize tray service
    await TrayService.instance.initialize();

    // Configure window to minimize to tray when closed
    windowManager.setPreventClose(true);
    windowManager.addListener(AppWindowListener());
  }

  runApp(const ApiServerApp());
}
