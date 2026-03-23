import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/owner/sync_loading_screen.dart';
import 'auth/change_password_screen.dart';
import 'constants.dart';
import 'globals.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'admin/admin_shell.dart';
import 'services/cache_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/no_internet_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('library'),
    Hive.openBox('staff'),
    Hive.openBox('seats'),
    Hive.openBox('students'),
    Hive.openBox('shifts'),
    Hive.openBox('combos'),
    Hive.openBox('lockers'),
    Hive.openBox('locker_policies'),
    Hive.openBox('seat_shifts'),
    Hive.openBox('notifications'),
    Hive.openBox('financial_events'),
    Hive.openBox('payment_records'),
  ]);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://zlhivlrapbhhkyrljueg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsaGl2bHJhcGJoaGt5cmxqdWVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM0ODU0MzgsImV4cCI6MjA4OTA2MTQzOH0.Mh3U8fz1RRfo4hAEI2gpmSU4jD_J5epWslXb9fAiNBg',
  );

  runApp(const LibraryOSApp());
}


class LibraryOSApp extends StatelessWidget {
  const LibraryOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LibraryOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInternet();
    // Real-time changes listen karo
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() => _hasInternet = results.any((r) => r != ConnectivityResult.none));
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    final results = await Connectivity().checkConnectivity();
    setState(() => _hasInternet = results.any((r) => r != ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet) {
      return NoInternetScreen(onRetry: _checkInternet);
    }

    // Normal app flow
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedOut) {
        // Cache clear karo
        await CacheService.clearAll();
        // Login screen pe bhejo
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // 1. Check Admin JWT
    final adminJwt = await storage.read(key: 'admin_jwt');
    if (adminJwt != null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminShell()),
          (route) => false,
        );
      }
      return;
    }

    // 2. Check Supabase Session
    final session = supabase.auth.currentSession;
    if (session != null) {
      await _resolveRoleAndNavigate(session.user.id);
      return;
    }

    // 3. No Session -> Home/Login
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _resolveRoleAndNavigate(String userId) async {
    try {
      final staffData = await supabase
          .from('staff')
          .select('role, force_password_change')
          .eq('user_id', userId)
          .single();

      final role = staffData['role'];
      final forceChange = staffData['force_password_change'] ?? false;
      
      // Set globals
      currentRole = role;
      final staffInfo = await supabase.from('staff').select('name, library_ids').eq('user_id', userId).single();
      currentLibraryId = staffInfo['library_ids'][0];
      currentUserName = staffInfo['name'] ?? '';

      if (!mounted) return;

      if (forceChange) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()), (route) => false);
        return;
      }

      if (role == 'owner' || role == 'staff') {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => SyncLoadingScreen(libraryId: currentLibraryId)), 
          (route) => false
        );
      } else {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }
}
