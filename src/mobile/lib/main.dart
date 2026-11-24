import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_locale.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'theme/nutriviet_glass.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
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
          scrollBehavior: const NutriVietScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
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
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xE8FFFFFF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFDDE5DF), width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFDDE5DF), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF14803C), width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFEF4444), width: 1.8),
              ),
              labelStyle:
                  const TextStyle(fontSize: 14.5, color: Color(0xFF64748B)),
              hintStyle:
                  const TextStyle(fontSize: 14.5, color: Color(0xFF94A3B8)),
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
