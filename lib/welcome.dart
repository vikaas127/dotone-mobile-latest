import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

/// Base constants
const String baseDomain = 'techdotbit.in';
const String scheme = 'https';
const String apiResolveUrl = 'https://techdotbit.in/saas/api/caddy_domain_check';
const Duration apiTimeout = Duration(seconds: 10);

/// ================== DOMAIN PAGE ==================
class DomainResolverPage extends StatefulWidget {
  const DomainResolverPage({super.key});

  @override
  State<DomainResolverPage> createState() => _DomainResolverPageState();
}

class _DomainResolverPageState extends State<DomainResolverPage> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool running = false;
  String status = 'Idle';
  String? _error;

  @override
  void initState() {
    super.initState();

    // Watch input changes to refresh "Continue" button state
    _ctrl.addListener(() {
      setState(() {});
    });
  }

  /// Ensure user granted location permissions
  Future<bool> _ensurePermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => status = 'Please enable Location Services (GPS).');
      return false;
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => status = 'Location permission denied.');
      return false;
    }
    return true;
  }
/*
  /// Resolve entered domain and navigate to webview
  Future<void> _resolveAndOpen() async {
    if (!await _ensurePermissions()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = 'Please enter your company domain.';
        _loading = false;
      });
      return;
    }

    try {
      // Start foreground tracking service
      final started = await FlutterForegroundTask.startService(
        notificationTitle: 'DOT Tracker is running',
        notificationText: 'Collecting location…',
        callback: startCallback,
      );

      setState(() {
        running = started;
        status = started ? 'Tracking…' : 'Failed to start service';
      });

      final fullDomain = input.contains(baseDomain)
          ? input
          : '$input.$baseDomain';
      final uri = Uri.parse('$apiResolveUrl?domain=$fullDomain');

      final res = await http.get(uri).timeout(apiTimeout);
      final body = res.body.trim().toLowerCase();

      if  (body.contains('matched')) {
        final finalUrl = Uri(scheme: scheme, host: fullDomain).toString();
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WebSiteHome(url: finalUrl)),
        );
      } else {
        throw Exception('Domain not found or not recognized.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unable to connect or domain not found.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  } */
  Future<void> _resolveAndOpen() async {
    if (kDebugMode) debugPrint('[DOT] Starting _resolveAndOpen()');

    // Step 1: Permissions
    if (kDebugMode) debugPrint('[DOT] Checking permissions...');
    if (!await _ensurePermissions()) {
      if (kDebugMode) debugPrint('[DOT] Permissions denied. Exiting.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Step 2: Input validation
    final input = _ctrl.text.trim();
    if (kDebugMode) debugPrint('[DOT] Raw input: "$input"');

    if (input.isEmpty) {
      setState(() {
        _error = 'Please enter your company domain.';
        _loading = false;
      });
      if (kDebugMode) debugPrint('[DOT] Error: Input empty.');
      return;
    }

    try {
      // Step 3: Clean and build domain
      final domainInput = input.replaceAll(RegExp(r'^https?://'), '').split('/').first;
      final fullDomain = domainInput.contains(baseDomain)
          ? domainInput
          : '$domainInput.$baseDomain';
      if (kDebugMode) debugPrint('[DOT] Processed domain: $fullDomain');

      // Step 4: Start foreground service
      /*   if (kDebugMode) debugPrint('[SERVICE] Starting foreground service...');
    final started = await FlutterForegroundTask.startService(
      notificationTitle: 'DOT Tracker is running',
      notificationText: 'Collecting location…',
      callback: startCallback,
    );

    setState(() {
      running = started;
      status = started ? 'Tracking…' : 'Failed to start service';
    });
*/
      if (kDebugMode) debugPrint('[SERVICE] Foreground start result: ');

      // Step 5: API call
      /*   final uri = Uri.parse('$apiResolveUrl?domain=$fullDomain');
    if (kDebugMode) debugPrint('[API] Request: $uri');
    final res = await http.get(uri).timeout(apiTimeout);

    if (kDebugMode) {
      debugPrint('[API] Status: ${res.statusCode}');
      debugPrint('[API] Body: ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}');
    }
*/
      // Step 6: Process response
      // if (res.statusCode == 200 && res.body.toLowerCase().contains('matched')) {
      final finalUrl = Uri(scheme: scheme, host: fullDomain).toString();
      if (kDebugMode) debugPrint('[DOT] Domain matched. Navigating to $finalUrl');

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WebSiteHome(url: finalUrl)),
      );
      // } else {
      //   if (kDebugMode) debugPrint('[DOT] Domain not matched.');
      //   throw Exception('Domain not found or not recognized.');
      //  }

    } on TimeoutException {
      if (kDebugMode) debugPrint('[ERROR] TimeoutException');
      if (mounted) setState(() => _error = 'Connection timed out. Please try again.');
    } on SocketException {
      if (kDebugMode) debugPrint('[ERROR] SocketException (No Internet)');
      if (mounted) setState(() => _error = 'No internet connection.');
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ERROR] Exception: $e');
        debugPrint('[STACK] $stack');
      }
      if (mounted) setState(() => _error = 'Unable to connect or domain not found.');
    } finally {
      if (kDebugMode) debugPrint('[DOT] Cleaning up (_loading = false)');
      if (mounted) setState(() => _loading = false);
    }

    if (kDebugMode) debugPrint('[DOT] _resolveAndOpen() finished.');
  }
  @override
  Widget build(BuildContext context) {
    final canSubmit = _ctrl.text.trim().isNotEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your company domain'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Company Domain',
                hintText: 'e.g. savit or savit.techdotbit.in',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(status, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            FilledButton.icon(
              icon: _loading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.login),
              label: Text(_loading ? 'Please wait...' : 'Continue'),
              onPressed: canSubmit ? _resolveAndOpen : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== WEBVIEW PAGE ==================
class WebSiteHome extends StatefulWidget {
  final String url;
  const WebSiteHome({super.key, required this.url});

  @override
  State<WebSiteHome> createState() => _WebSiteHomeState();
}

class _WebSiteHomeState extends State<WebSiteHome> {
  late final WebViewController _controller;
  final tracker = BackgroundTracker();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    tracker.initialize();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'DOTChannel',
        onMessageReceived: (msg) async {
          if (msg.message == 'checkin') {
            await tracker.start();
          } else if (msg.message == 'checkout') {
            await tracker.stop();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.url)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

/// ================== BACKGROUND TRACKING ==================
@pragma('vm:entry-point')
void callbackDispatcher() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated((location) async {
    // Runs in the background isolate.
    // You can post lightweight API calls here.
  });
}

class BackgroundTracker {
  bool trackingActive = false;
  double totalDistance = 0.0;
  Position? lastPosition;

  Future<void> initialize() async {
    await BackgroundLocationTrackerManager.initialize(
      callbackDispatcher,
      config: BackgroundLocationTrackerConfig(
        loggingEnabled: true,
        androidConfig: const AndroidConfig(
          channelName: 'DOT Tracker Service',
          notificationBody: 'Tracking your work-day movement...',
          cancelTrackingActionText: 'Stop Tracking',
          enableCancelTrackingAction: true,
          enableNotificationLocationUpdates: true,
          trackingInterval: Duration(seconds: 15),
          distanceFilterMeters: 10,
        ),
        iOSConfig: IOSConfig(
          activityType: ActivityType.AUTOMOTIVE,
          distanceFilterMeters: 10,
          restartAfterKill: true,
        ),
      ),
    );

    BackgroundLocationTrackerManager.handleBackgroundUpdated((location) async {
      if (!trackingActive) return;

      final lat = location.lat;
      final lng = location.lon;

      if (lastPosition != null) {
        totalDistance += Geolocator.distanceBetween(
          lastPosition!.latitude,
          lastPosition!.longitude,
          lat,
          lng,
        );
      }

      lastPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      await sendToServer(lat, lng, totalDistance);
    });
  }

  Future<void> start() async {
    trackingActive = true;
    await BackgroundLocationTrackerManager.startTracking();
    debugPrint("📡 DOT Tracker Started");
  }

  Future<void> stop() async {
    trackingActive = false;
    await BackgroundLocationTrackerManager.stopTracking();
    debugPrint("🛑 DOT Tracker Stopped");
  }

  Future<void> sendToServer(double lat, double lng, double distance) async {
    final deviceInfo = DeviceInfoPlugin();
    final device = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : 'Other';

    await http.post(
      Uri.parse('https://techdotbit.in/saas/api/save_location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': 'USER123', // Replace with actual logged-in user
        'device': device,
        'lat': lat,
        'lng': lng,
        'distance': distance.toStringAsFixed(2),
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }
}
