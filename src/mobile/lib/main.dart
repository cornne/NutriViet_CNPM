import 'dart:io';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'l10n/app_locale.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassShaders.ensureLoaded();
  await AppLocale.loadSaved();
  final session = await AuthService.getSession();
  runApp(NutriVietApp(initialUser: session));
}

class NutriVietApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;

  const NutriVietApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'NutriViet',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF3F6F3),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF14803C),
              primary: const Color(0xFF14803C),
              secondary: const Color(0xFF4F37C8),
              surface: const Color(0xFFFFFFFF),
              error: const Color(0xFFDC2626),
            ),
            fontFamily: 'Roboto',
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
              ),
              labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ),
          home: initialUser != null
              ? HomeScreen(user: initialUser!)
              : const LoginScreen(),
        );
      },
    );
  }
}
