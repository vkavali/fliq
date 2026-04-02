import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String kFliqUrl = 'https://fliq.co.in/app/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: FliqApp()));
}

class FliqApp extends StatelessWidget {
  const FliqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fliq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const FliqWebView(),
    );
  }
}

class FliqWebView extends StatefulWidget {
  const FliqWebView({super.key});

  @override
  State<FliqWebView> createState() => _FliqWebViewState();
}

class _FliqWebViewState extends State<FliqWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1a1145))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          // Allow fliq.co.in and UPI deep links
          final uri = Uri.parse(request.url);
          if (uri.host.contains('fliq.co.in') ||
              uri.host.contains('railway.app') ||
              uri.scheme == 'upi') {
            return NavigationDecision.navigate;
          }
          // Open external links in browser
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(kFliqUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1145),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF6C5CE7),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading Fliq...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
