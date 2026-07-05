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
      // Modo noturno é a identidade do app; o tema claro fica disponível
      // para uma futura preferência do usuário.
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}
