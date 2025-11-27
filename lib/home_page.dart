import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/api_service.dart';
import '../services/location_tracker.dart';
import '../services/HistoryModel.dart';
import 'MapTrackingPage.dart';
import 'package:app_settings/app_settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  bool isCheckedIn = false;
  bool disableButtons = false;
  bool _isOffline = false;
  bool _locationOffWarningShown = false;

  bool loading = true;
  bool _trackingInitialized = false;
  String status = 'Idle';
  String? username, useremail;
  List<Data> history = [];

  final api = ApiService();
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    _initializeOnce();
  }

  // -------------------- OFFLINE ATTENDANCE MANAGEMENT --------------------
  Future<File> _getOfflineFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_attendance.json');
  }

  // Save offline check-in/out when no internet
  Future<void> _saveOfflineAttendance(Map<String, dynamic> entry) async {
    try {
      final file = await _getOfflineFile();
      List<dynamic> existing = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) existing = jsonDecode(content);
      }
      existing.add(entry);
      await file.writeAsString(jsonEncode(existing));
      print("💾 [Offline] Saved ${entry['type']} at ${entry['timestamp']}");
    } catch (e) {
      print("⚠️ [Offline] Failed to save attendance: $e");
    }
  }

  // Upload saved offline check-in/out
  // -------------------- UPLOAD OFFLINE ATTENDANCE (Batch Mode) --------------------
  Future<void> _uploadOfflineAttendance() async {
    try {
      final file = await _getOfflineFile();
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      List<dynamic> saved = jsonDecode(content);
      if (saved.isEmpty) return;

      // ✅ Sort oldest to newest (just in case)
      saved.sort(
        (a, b) => DateTime.parse(
          a['timestamp'],
        ).compareTo(DateTime.parse(b['timestamp'])),
      );

      final List<dynamic> remaining = [];
      int successCount = 0;

      print("📦 [Offline Sync] Found ${saved.length} pending offline records");

      // ✅ Process in batches of 50
      for (int i = 0; i < saved.length; i += 50) {
        final batch = saved.skip(i).take(50).toList();
        print(
          "🚀 [Offline Sync] Uploading batch ${i ~/ 50 + 1} (${batch.length} records)",
        );

        for (var entry in batch) {
          try {
            if (entry['type'] == 'checkin') {
              await api.checkin(entry['lat'], entry['lng']);
            } else if (entry['type'] == 'checkout') {
              await api.checkout(entry['lat'], entry['lng']);
            }
            successCount++;
          } catch (e) {
            print(
              "⚠️ [Offline Sync] Failed ${entry['type']} (${entry['timestamp']}): $e",
            );
            remaining.add(entry);
          }
        }

        // ✅ Small delay between batches to avoid server overload
        await Future.delayed(const Duration(seconds: 2));
      }

      // ✅ Save only remaining unsynced entries
      await file.writeAsString(jsonEncode(remaining));

      if (successCount > 0) {
        print("✅ [Offline Sync] Uploaded $successCount records successfully");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Synced $successCount offline records successfully.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print(
          "⚠️ [Offline Sync] No records uploaded — all failed or already synced",
        );
      }
    } catch (e) {
      print("❌ [Offline Sync] Error syncing offline data: $e");
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void> _initializeOnce() async {
    if (_trackingInitialized) return;
    _trackingInitialized = true;

    print("⚙️ [HomePage] Initializing background and offline sync services...");
    if (_connectivitySub != null) {
      print(
        "⚠️ [Init] Connectivity listener already running, skipping re-init.",
      );
      return;
    }
    // 🟢 Connectivity listener — update UI + sync when back online
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final hasConnection =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      if (hasConnection) {
        setState(() => _isOffline = false);
        print(
          "🌐 [Offline Sync] Internet restored — syncing saved check-ins...",
        );
        await _uploadOfflineAttendance();
      } else {
        setState(() => _isOffline = true);
        print("🚫 [Offline] Network offline");
      }
    });

    // 🕒 Periodically check if location is turned off (every 15 sec)
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !_locationOffWarningShown && mounted) {
        _locationOffWarningShown = true;
        _showLocationOffPopup();
      }
    });

    await initForegroundService();
    await _loadCurrentStatus();
    await _loadHistory();
    showBackgroundPermissionDialog(context);
    _checkPermission();
    print("✅ [HomePage] Initialization complete.");
  }

  void _showLocationOffPopup() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Disabled'),
        content: const Text(
          'We are tracking your location in background for attendance.\n\n'
          'Please enable GPS to ensure accurate tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _locationOffWarningShown = false;
            },
            child: const Text('Ignore'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _locationOffWarningShown = false;
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // -------------------- LOAD CURRENT STATUS --------------------
  Future<void> _loadCurrentStatus() async {
    try {
      final res = await api.getCurrentStatus();
      if (!mounted) return;

      if (res['message'] == 'Invalid token' && res['success'] == false) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_token');
        Navigator.pushNamed(context, '/login');
        return;
      }

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final typeCheck = int.tryParse(data['type_check'].toString()) ?? 0;

        setState(() {
          loading = false;
          isCheckedIn = typeCheck == 1;
          status = isCheckedIn
              ? 'Already Checked In (Pending Checkout)'
              : 'Checked Out';
        });

        if (isCheckedIn && !_trackingInitialized) {
          _trackingInitialized = true;
          await startTracking();
        }
        final isRunning = await FlutterForegroundTask.isRunningService;
        if (isCheckedIn && !isRunning) {
          print("🔁 [Auto-Resume] Restarting tracking after app restart...");
          await startTracking();
        }
      } else {
        setState(() {
          loading = false;
          isCheckedIn = false;
          disableButtons = false;
          status = 'Not Checked In';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        status = 'Failed to fetch status: $e';
      });
    }
  }

  // -------------------- LOCATION PERMISSION --------------------
  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Disabled'),
          content: const Text(
            'Your location service (GPS) is turned off.\n\nPlease enable location services to Check-In or Check-Out.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return false;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Denied'),
            content: const Text(
              'Location permission is required to use this feature.\nPlease allow location access to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Permanently Denied'),
          content: const Text(
            'You have permanently denied location permission.\n\nPlease go to App Settings and enable it manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> showBackgroundPermissionDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final brand = androidInfo.brand?.toLowerCase() ?? '';
    final manufacturer = androidInfo.manufacturer?.toLowerCase() ?? '';

    // 🔍 Detect OEMs known for killing background tasks
    final restrictedOEMs = [
      'xiaomi',
      'vivo',
      'oppo',
      'realme',
      'huawei',
      'oneplus',
    ];

    if (restrictedOEMs.contains(brand) ||
        restrictedOEMs.contains(manufacturer)) {
      // 🧭 Show popup
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Allow Background Run'),
            content: const Text(
              'Your phone may stop location tracking when the app is closed.\n\n'
              'To ensure continuous tracking, please allow the app to run in the background.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                child: const Text('Later'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  Navigator.pop(context);
                  AppSettings.openAppSettings(); // Opens app settings directly
                },
              ),
            ],
          ),
        );
      }
    }
  }

  // -------------------- TRACKING START / STOP --------------------
  Future<void> startTracking() async {
    print("🚀 [HomePage] Attempting to start foreground location tracking...");

    // Prevent duplicate starts
    final bool isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      print(
        "⚠️ [HomePage] Foreground service already running — skipping start",
      );
      return;
    }

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'DOT Tracking Active',
        notificationText: 'Tracking your live location...',
        callback: startCallback,
      );
      print("✅ [HomePage] Foreground service started successfully");
    } catch (e) {
      print("❌ [HomePage] Failed to start service: $e");
    }
  }

  Future<void> stopTracking() async {
    try {
      final bool isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        print("⚠️ [HomePage] Foreground service not running — skip stop");
        return;
      }
      await FlutterForegroundTask.stopService();
      print("🛑 [HomePage] Foreground tracking stopped successfully");
    } catch (e) {
      print("❌ [HomePage] Error stopping tracking: $e");
    }
  }

  // -------------------- CHECK-IN / CHECK-OUT --------------------
  Future<void> _checkInOut() async {
    if (!await _checkPermission()) return;

    setState(() {
      disableButtons = true;
      loading = true;
      status = 'Processing...';
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final conn = await Connectivity().checkConnectivity();
      final isOnline = conn != ConnectivityResult.none;

      // ------------------ OFFLINE CASE ------------------
      if (!isOnline) {
        final entry = {
          "type": isCheckedIn ? "checkout" : "checkin",
          "lat": pos.latitude,
          "lng": pos.longitude,
          "timestamp": DateTime.now().toIso8601String(),
        };
        await _saveOfflineAttendance(entry);

        setState(() {
          isCheckedIn = !isCheckedIn;
          status = isCheckedIn
              ? 'Checked In (Offline Mode)'
              : 'Checked Out (Offline Mode)';
        });

        // 🔄 Re-enable buttons after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => disableButtons = false);
        });

        // 🟡 Show Offline Snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📡 No internet! ${entry['type'].toString().toUpperCase()} saved offline and will sync when online.',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        return;
      }

      // ------------------ ONLINE CASE ------------------
      final res = isCheckedIn
          ? await api.checkout(pos.latitude, pos.longitude)
          : await api.checkin(pos.latitude, pos.longitude);

      if (!mounted) return;

      if (res['success']) {
        final typeCheck =
            int.tryParse(res['data']['type_check'].toString()) ?? 0;
        final bool nowCheckedIn = typeCheck == 1;

        setState(() {
          isCheckedIn = nowCheckedIn;
          status = nowCheckedIn
              ? 'Checked In Successfully'
              : 'Checked Out Successfully';
        });

        // ✅ Show Success Snackbar at bottom
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nowCheckedIn
                    ? '✅ You have successfully Checked In!'
                    : '👋 You have successfully Checked Out!',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: nowCheckedIn
                  ? Colors.green.shade600
                  : Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Start or stop background tracking
        if (nowCheckedIn) {
          _trackingInitialized = true;
          await startTracking();
        } else {
          _trackingInitialized = false;
          await stopTracking();
        }

        await _loadHistory();
      } else {
        setState(() => status = res['message']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${res['message']}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        disableButtons = false;
        loading = false;
      });
    }
  }

  // -------------------- PROFILE --------------------
  void fetchProfile() async {
    final response = await api.getProfile();
    if (response['success'] == true) {
      final user = response['data']['user'];
      username = user['name'];
      useremail = user['email'];
    } else {
      print("⚠️ Failed to load profile: ${response['message']}");
    }
  }

  // -------------------- HISTORY --------------------
  Future<void> _loadHistory() async {
    try {
      loading = true;
      final historyModel = await api.getAttendanceHistory();
      if (!mounted) return;
      setState(() {
        loading = false;
        history = historyModel.data ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        status = 'Failed to load history: $e';
      });
    }
  }

  // -------------------- LOGOUT --------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    if (!mounted) return;
    await stopTracking();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _positionStream?.cancel();
    _positionStream = null;
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isOffline)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange),
                      SizedBox(width: 5),
                      Text(
                        "You’re offline — we’ll sync data once online.",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              if (isCheckedIn)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.green),
                      SizedBox(width: 5),
                      Text(
                        "Tracking Active",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Check-In / Check-Out Buttons with Loader
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: (loading && !isCheckedIn)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: (loading && !isCheckedIn)
                        ? const Text('Processing...')
                        : const Text('Check-In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: disableButtons || isCheckedIn
                          ? Colors.grey
                          : Colors.green,
                      minimumSize: const Size(150, 50),
                    ),
                    onPressed: disableButtons || isCheckedIn
                        ? null
                        : () => _checkInOut(),
                  ),
                  ElevatedButton.icon(
                    icon: (loading && isCheckedIn)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: (loading && isCheckedIn)
                        ? const Text('Processing...')
                        : const Text('Check-Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: disableButtons || !isCheckedIn
                          ? Colors.grey
                          : Colors.red,
                      minimumSize: const Size(150, 50),
                    ),
                    onPressed: disableButtons || !isCheckedIn
                        ? null
                        : () => _checkInOut(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Check-In/Check-Out History',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )
              else if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No attendance records found.'),
                )
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.80,
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final dayData = history[index];
                      final date = dayData.date ?? '-';
                      final records = dayData.records ?? [];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.map,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapTrackingPage(
                                        date: date,
                                        lat: double.parse(records[0].lat!),
                                        lng: double.parse(records[0].long!),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          children: records.map((r) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        r.typeCheck == '1'
                                            ? Icons.login
                                            : Icons.logout,
                                        color: r.typeCheck == '1'
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      Text(
                                        ' ${r.typeCheck == '1' ? 'Check-in' : 'Check-out'}',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Time: ${r.date != null ? DateFormat('h:mm a').format(DateTime.parse(r.date!)) : '-'}',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      r.address != null
                                          ? '📍 ${r.address}'
                                          : '',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
