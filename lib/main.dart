import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'services/favorites_service.dart';
import 'services/governorate_service.dart';

// ---------------- هوية الألوان: برتقالي حيوي (طاقة/وقود) + تباين داكن قوي ----------------
const Color _primary = Color(0xFFFF6A00); // برتقالي ناري
const Color _primaryDark = Color(0xFFC43E00); // برتقالي محروق (للتباين والتدرّج)
const Color _secondary = Color(0xFF00838F); // سيان داكن مكمّل
const Color _tertiary = Color(0xFFFFC400); // أصفر/كهرماني للّمسات البارزة

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await FavoritesService.instance.load();
  await GovernorateService.instance.load();
  runApp(const MosulGasApp());
}

class MosulGasApp extends StatelessWidget {
  const MosulGasApp({super.key});

  @override
  Widget build(BuildContext context) {
    // نبني اللوحة من seed ثم نفرض الألوان الأساسية بأنفسنا، لأن توليد Material 3 التلقائي
    // من seed يميل لتلوين باهت لأسباب تباين؛ هذا يضمن ألواناً زاهية فعلاً كما طُلب.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: _primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      tertiary: _tertiary,
      onTertiary: Colors.black,
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: kAppName,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFF6EE),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? _primary : null),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? Colors.white : null),
          ),
        ),
        chipTheme: ChipThemeData(
          selectedColor: _primary,
          secondarySelectedColor: _primary,
          labelStyle: const TextStyle(color: Colors.black87),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: _primary.withAlpha(40),
          backgroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
      ),
      home: const BootScreen(),
    );
  }
}

/// يهيّئ Firebase ويسجّل دخولاً مجهولاً (بدون حساب) ثم يفتح الشاشة الرئيسية.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  late Future<void> _init = _initialize();

  Future<void> _initialize() async {
    await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'تعذّر الاتصال بالخادم.\nتحقق من الإنترنت وحاول مرة أخرى.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _init = _initialize()),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const HomeShell();
      },
    );
  }
}
