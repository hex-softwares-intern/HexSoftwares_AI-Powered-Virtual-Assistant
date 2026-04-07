import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/assistant_screen.dart';

class AiAssistantApp extends StatelessWidget {
  const AiAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARIA',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      home: const AssistantScreen(),
    );
  }
}
