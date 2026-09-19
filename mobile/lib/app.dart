import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/settings/providers/settings_providers.dart';
import 'shell/home_shell.dart';

class McqApp extends ConsumerWidget {
  const McqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Hayat Form',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: switch (authState.status) {
        AuthStatus.initial => const SplashScreen(),
        AuthStatus.authenticating => const LoginScreen(),
        AuthStatus.authenticated => const HomeShell(),
        AuthStatus.unauthenticated => const LoginScreen(),
      },
    );
  }
}
