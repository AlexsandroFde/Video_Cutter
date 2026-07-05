import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/cutter/presentation/pages/home_page.dart';

class VideoCutterApp extends StatelessWidget {
  const VideoCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Cutter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomePage(),
    );
  }
}
