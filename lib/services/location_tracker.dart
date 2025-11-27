import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dotone/services/api_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _sub;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Timer? _flushTimer;

  // ✅ Queue of points not yet sent to server
  final List<Map<String, dynamic>> _queue = [];

  // ✅ For movement / timing checks
  Position? _lastSentPosition;
  DateTime _lastSentTime = DateTime.now();

  static const double minDistanceToSend = 200.0; // meters
  static const Duration maxInterval = Duration(minutes: 5);
  static const int batchSize = 15;

  // --------------------------
  // 🚀 START LOCATION STREAM
  // --------------------------
  Future<void> _startStream() async {
    print("🟡 [Tracker] Starting adaptive location tracking stream...");

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      print("⚙️ [Tracker] Location permission requested");
    }
    if (perm == LocationPermission.deniedForever) {
      print('❌ [Tracker] Location permission permanently denied');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      print('⚠️ [Tracker] Location services disabled');
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );

    // ✅ Continuous location updates
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
          (pos) async {
        final now = DateTime.now();

        if (_lastSentPosition == null) {
          _lastSentPosition = pos;
          _lastSentTime = now;
          _queue.add(_buildLocationMap(pos));
          await _saveOffline(); // save even first point
          print("📍 [Tracker] First location queued (offline-safe)");
          return;
        }

        final distanceMoved = Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        final timeSinceLastSend = now.difference(_lastSentTime);

        if (distanceMoved >= minDistanceToSend ||
            timeSinceLastSend >= maxInterval) {
          _queue.add(_buildLocationMap(pos));
          _lastSentPosition = pos;
          _lastSentTime = now;
          await _saveOffline();
          print("📦 [Tracker] Added new point: moved ${distanceMoved.toStringAsFixed(1)}m");

          if (_queue.length >= batchSize) {
            await _flush();
          }
        }

        // Update notification every time
        FlutterForegroundTask.updateService(
          notificationTitle: 'DOT Tracking Active',
          notificationText:
          'Last update: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
        );
      },
      onError: (e) => print("❌ [Tracker] Stream error: $e"),
    );
  }

  // --------------------------
  // 🔹 BUILD LOCATION MAP
  // --------------------------
  Map<String, dynamic> _buildLocationMap(Position pos) => {
    "lat": pos.latitude,
    "lng": pos.longitude,
    "accuracy": pos.accuracy,
    "recorded_at": DateTime.now().toUtc().toIso8601String(),
    "device_id": "DEVICE-${DateTime.now().millisecondsSinceEpoch}",
  };

  // --------------------------
  // 🔹 SAVE QUEUE OFFLINE
  // --------------------------
  Future<void> _saveOffline() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_locations.json');
      await file.writeAsString(jsonEncode(_queue));
      print("💾 [Offline] Saved ${_queue.length} pending points");
    } catch (e) {
      print("⚠️ [Offline] Save failed: $e");
    }
  }

  // --------------------------
  // 🔹 LOAD QUEUE ON START
  // --------------------------
  Future<void> _loadOfflineQueue() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_locations.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> saved = jsonDecode(content);
          _queue.clear();
          _queue.addAll(saved.cast<Map<String, dynamic>>());
          print("📂 [Offline] Restored ${_queue.length} saved locations");
        }
      }
    } catch (e) {
      print("⚠️ [Offline] Load failed: $e");
    }
  }

  // --------------------------
  // 🔹 SEND TO SERVER
  // --------------------------
  Future<void> _flush() async {
    if (_queue.isEmpty) return;

    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      print("⚠️ [Tracker] Offline — skipping upload");
      await _saveOffline();
      return;
    }

    print("📤 [Tracker] Attempting to send ${_queue.length} points...");

    try {
      final api = ApiService();
      final payload = List<Map<String, dynamic>>.from(_queue);
      final res = await api.storeelocation(payload: payload);

      if (res['success'] == true) {
        print("✅ [Tracker] Sent ${payload.length} points successfully");
        _queue.clear();
        await _saveOffline(); // clear file
      } else {
        print("⚠️ [Tracker] Server rejected upload: ${res['message']}");
        await _saveOffline();
      }
    } catch (e) {
      print("❌ [Tracker] Flush error: $e");
      await _saveOffline();
    }
  }

  // --------------------------
  // 🔹 AUTO SYNC WHEN ONLINE
  // --------------------------
  void _monitorConnectivity() {
    StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // `results` may contain multiple values like [wifi, mobile]
      final hasConnection = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      if (hasConnection) {
        print("🌐 [Tracker] Internet restored — syncing offline data...");
        await _flush();
      }
    });

  }

  // --------------------------
  // 🔹 FOREGROUND SERVICE HANDLERS
  // --------------------------
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print("🚀 [Tracker] Background tracking started at $timestamp");
    await _loadOfflineQueue();
    await _startStream();
    _monitorConnectivity();

    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) => _flush());
  }

  @override
  Future<void> onEvent(DateTime timestamp) async {
    await _flush();
  }

  @override
  void onButtonPressed(String id) async {
    if (id == 'stop') await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sub?.cancel();
    await _connectivitySub?.cancel();
    _flushTimer?.cancel();
    await _saveOffline();
    print("🛑 [Tracker] Service stopped at $timestamp (timeout: $isTimeout)");
  }

  @override
  void onRepeatEvent(DateTime timestamp) {

  }
}

// --------------------------
// 🔹 ENTRY POINT
// --------------------------
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}


Future<void> initForegroundService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'dot_loc_channel',
      channelName: 'DOT Live Location',
      channelDescription: 'Tracks background GPS updates',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
      eventAction: ForegroundTaskEventAction.repeat(5000),
       // replaces restartOnKill in most cases
      autoRunOnMyPackageReplaced: true,
    ),
  );

}
