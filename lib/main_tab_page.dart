import 'package:dotone/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainTabPage extends StatefulWidget {
  final String? url;
  const MainTabPage({super.key, this.url});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedIndex = 0;
  List<Widget> _pages = [];

  @override
  void initState() {
    webview();
    fetchProfile();
    super.initState();
  }

  String? _baseUrl;
  String? username, useremail;
  final api = ApiService();
  webview() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url') ?? 'https://techdotbit.in/';

    _pages = [
      HomePage(), // ✅ your existing attendance page
      WebViewTab(url: '${_baseUrl}/admin'), // ✅ dashboard tab
    ];
  }

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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    if (!mounted) return;
    // await stopTracking();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.green, size: 35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username != null
                        ? 'Welcome, $username'
                        : 'Welcome to DotOne',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    useremail ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text('Daily Activities'),
        backgroundColor: Colors.green,
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

class WebViewTab extends StatefulWidget {
  final String url;
  const WebViewTab({super.key, required this.url});

  @override
  State<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends State<WebViewTab> {
  late final WebViewController _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Optional: You can show progress if needed
          },
          onPageStarted: (String url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('⚠️ HTTP error: ${error.response?.statusCode}');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🚨 Resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Example restriction
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
