import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/home_screen.dart';
import 'utils/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android/iOS/macOS use the native sqflite plugin; Windows/Linux need FFI.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await AppSettings.load();
  runApp(const StringsPharmacyApp());
}

class StringsPharmacyApp extends StatelessWidget {
  const StringsPharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00897B);
    return MaterialApp(
      title: 'Strings Pharmacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const HomeScreen(),
    );
  }
}
