import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/shared_widgets.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Attempt to initialize Firebase
    if (DefaultFirebaseOptions.web.apiKey != 'FIREBASE_API_KEY_PLACEHOLDER') {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Disable Firestore offline persistence on Web to make write/commit operations instant (under 0.5s)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      debugPrint("Firebase services initialized successfully.");
    } else {
      debugPrint("Firebase credentials are placeholder.");
    }
  } catch (e) {
    debugPrint("Firebase connection failed: $e.");
  }

  // Pre-load receipt logo and barcode into memory as base64 so print is instant
  await preloadReceiptLogo();
  await preloadBarcode();

  // Override default Flutter error widget to show a beautiful fallback screen instead of the red screen of death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final bool isNetworkError = details.exception.toString().toLowerCase().contains('network') ||
        details.exception.toString().toLowerCase().contains('internet') ||
        details.exception.toString().toLowerCase().contains('connection') ||
        details.exception.toString().toLowerCase().contains('socketexception') ||
        details.exception.toString().toLowerCase().contains('unavailable') ||
        details.exception.toString().toLowerCase().contains('failed host lookup');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isNetworkError ? Icons.wifi_off : Icons.error_outline,
                color: isNetworkError ? Colors.orange : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isNetworkError ? "No Internet Connection" : "An Error Occurred",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                isNetworkError 
                  ? "Please check your internet connection and try again."
                  : details.exception.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    const ProviderScope(
      child: BossFoodCornerApp(),
    ),
  );
}

class BossFoodCornerApp extends ConsumerWidget {
  const BossFoodCornerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Boss Food Corner POS',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
