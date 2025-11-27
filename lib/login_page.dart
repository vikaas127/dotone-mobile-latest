import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'main_tab_page.dart';



class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final domainCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final api = ApiService();

  bool domainVerified = false;
  bool loading = false;
  String? error;

  Future<void> _verifyDomain() async {
    setState(() {
      loading = true;
      error = null;
    });

    final res = await api.checkDomain(domainCtrl.text.trim());
    setState(() => loading = false);

    if (res['success'] == true) {
      setState(() => domainVerified = true);
    } else {
      setState(() => error = res['message']);
    }
  }

  Future<void> _login() async {
    setState(() => loading = true);
    final res = await api.login(emailCtrl.text.trim(), passCtrl.text.trim());
    setState(() => loading = false);

    if (res['success'] == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>  MainTabPage()));
    } else {
      setState(() => error = res['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'),backgroundColor: Colors.green,),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset("assets/images/logo.png",width: 200,height: 100,),
            if (!domainVerified) ...[
              const SizedBox(height: 40),
              TextField(
                controller: domainCtrl,
                decoration:  InputDecoration(
                  labelText: ' Enter your Company Domain ',
                  hint: Text('e.g. abc.techdotbit.in',),focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.indigo, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],)

              ),
              const SizedBox(height: 142),
              ElevatedButton(
                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.green),
                  foregroundColor: WidgetStateProperty.all(Colors.white), ),
                onPressed: loading ? null : _verifyDomain,
                child: Text(loading ? 'Verifying...' : 'Verify Company'),
              ),
            ],
            if (domainVerified) ...[
              const SizedBox(height: 40),
              TextField(
                controller: emailCtrl,
                decoration:  InputDecoration(labelText: 'Email',focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.indigo, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password',focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.indigo, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],),
              ),
              const SizedBox(height: 142),
              ElevatedButton(
                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.green),
                  foregroundColor: WidgetStateProperty.all(Colors.white), ),
                onPressed: loading ? null : _login,
                child: Text(loading ? 'Logging in...' : 'Login'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
