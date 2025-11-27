import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'MapTrackingPage.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'main_tab_page.dart';
import 'services/location_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("🟡 [main] Flutter binding initialized");

  try {
    await initForegroundService();
    print("✅ [main] Foreground service initialized successfully");
  } catch (e) {
    print("❌ [main] Foreground service init failed: $e");
  }

  runApp(const DotOneApp());
}

class DotOneApp extends StatelessWidget {
  const DotOneApp({super.key});

  Future<Widget> _getStartPage() async {
    print("🔍 [DotOneApp] Checking stored login credentials...");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final tenantUrl = prefs.getString('tenant_base_url');

    if (token != null && tenantUrl != null) {
      print("✅ [DotOneApp] Token found → redirecting to HomePage");
      return const  MainTabPage();
    } else {
      print("ℹ️ [DotOneApp] No login found → redirecting to LoginPage");
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    print("⚙️ [DotOneApp] Building MaterialApp...");

    return WithForegroundTask(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DOT Tracker',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        routes: {
          '/mapTracking': (context) =>
          const MapTrackingPage(date: '2025-10-28', lat: 22.4, lng: 44.5,),
          '/login': (context) => LoginPage(),
        },
        home: FutureBuilder<Widget>(
          future: _getStartPage(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              print("❌ [DotOneApp] Error: ${snapshot.error}");
              return const Scaffold(
                body: Center(child: Text('Something went wrong!')),
              );
            }
            return snapshot.data ?? const LoginPage();
          },
        ),
      ),
    );
  }
}
