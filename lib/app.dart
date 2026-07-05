import 'package:flutter/material.dart';

import 'core/design/app_theme.dart';
import 'features/cutter/presentation/pages/home_page.dart';

class VideoCutterApp extends StatelessWidget {
  const VideoCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Cutter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
