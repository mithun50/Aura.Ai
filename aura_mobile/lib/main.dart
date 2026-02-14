import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/presentation/pages/chat_screen.dart';
import 'package:aura_mobile/presentation/pages/model_download_screen.dart';
import 'package:aura_mobile/core/services/notification_service.dart';
import 'package:aura_mobile/core/services/app_usage_tracker.dart';
import 'package:aura_mobile/core/services/daily_summary_scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura_mobile/ai/run_anywhere_service.dart';
import 'dart:isolate';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FlutterDownloader
  await FlutterDownloader.initialize(
    debug: true, // debug: false to disable console log
    ignoreSsl: true // option: false to disable working with http links
  );

  // Initialize RunAnywhere to sync downloads
  try {
    await RunAnywhere().initialize();
  } catch (e) {
    print("RunAnywhere initialization failed: $e");
  }

  // Initialize notification system
  final notificationService = NotificationService();
  await notificationService.requestPermissions();
  await notificationService.initialize();
  
  // Initialize app usage tracking
  final appUsageTracker = AppUsageTracker();
  await appUsageTracker.trackAppOpen();
  
  // Initialize daily summary scheduler
  await DailySummaryScheduler.initialize();
  
  runApp(
    const ProviderScope(
      child: AuraApp(),
    ),
  );
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0a0c),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: const Color(0xFFEDEDED)),
        ),
        useMaterial3: true,
      ),
      home: const ModelDownloadScreen(),
      routes: {
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
