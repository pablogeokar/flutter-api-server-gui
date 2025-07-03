import 'package:flutter/material.dart';
import 'package:flutter_api_gui/pages/home_page.dart';
import 'theme.dart';

class ApiServerApp extends StatelessWidget {
  const ApiServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🚀 API Server Local',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
