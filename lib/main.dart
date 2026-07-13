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

  // Pre-load receipt logo into memory as base64 so print is instant
  await preloadReceiptLogo();

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
