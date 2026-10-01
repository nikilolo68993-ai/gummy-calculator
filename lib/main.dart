import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'engine/calculator.dart';
import 'ui/flavor.dart';
import 'ui/calculator_screen.dart';

bool get isDesktop =>
    !kIsWeb &&
    {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // Calculation remains available even when local storage is unavailable.
  }
  if (isDesktop) await windowManager.ensureInitialized();
  runApp(
    GummyApp(
      calculator: Calculator(preferences: preferences),
      desktop: isDesktop,
    ),
  );
  if (isDesktop) {
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1180, 860),
        minimumSize: Size(460, 720),
        center: true,
        title: 'Gummy — мягкая математика',
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Flavor.paper,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
}

class GummyApp extends StatelessWidget {
  const GummyApp({super.key, required this.calculator, this.desktop = false});
  final Calculator calculator;
  final bool desktop;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Gummy',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: Flavor.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Flavor.all.first.accent,
        brightness: Brightness.light,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Manrope',
        bodyColor: Flavor.ink,
        displayColor: Flavor.ink,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Flavor.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Flavor.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Flavor.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: CalculatorScreen(calculator: calculator, desktop: desktop),
  );
}
