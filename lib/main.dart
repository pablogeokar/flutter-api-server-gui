import 'package:flutter/material.dart';
import 'api_server_app.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

void main() async {
  /**
   * significa garantir que a ligação entre o Flutter e o engine (motor de renderização) 
   * esteja pronta antes de executar qualquer código que dependa dela. Ele é geralmente 
   * usado no início da função main(), especialmente quando você precisa fazer alguma 
   * inicialização assíncrona ou trabalhar com plugins antes de rodar o runApp().
   * 
   * Sem essa linha, você pode encontrar erros como:
   * 
   * "Binding has not been initialized."
   */
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Servidor de API',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(ApiServerApp());
}
