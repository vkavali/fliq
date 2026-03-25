import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (requires google-services.json / GoogleService-Info.plist).
  // Falls back gracefully if config files are missing.
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  runApp(const ProviderScope(child: FliqApp()));
}

class FliqApp extends ConsumerStatefulWidget {
  const FliqApp({super.key});

  @override
  ConsumerState<FliqApp> createState() => _FliqAppState();
}

class _FliqAppState extends State<FliqApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotifications());
  }

  Future<void> _initNotifications() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    final notifService = container.read(notificationServiceProvider);
    await notifService.initialize();

    // Show foreground notifications as snack bars
    notifService.listenForeground((title, body, screen) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(body, style: const TextStyle(fontSize: 13)),
            ],
          ),
          action: screen != null
              ? SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    final router = container.read(appRouterProvider);
                    router.go(screen);
                  },
                )
              : null,
          duration: const Duration(seconds: 5),
        ),
      );
    });

    // Handle notification tap deep-link
    final router = container.read(appRouterProvider);
    notifService.listenTaps((screen) => router.go(screen));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          title: 'Fliq',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          routerConfig: router,
        );
      },
    );
  }
}
