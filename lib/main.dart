import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/parent_context_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/parent_profile_screen.dart';
import 'screens/select_child_screen.dart';
import 'screens/select_establishment_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'package:app_links/app_links.dart';
import 'screens/auth/reset_password_screen.dart';
import 'dart:async';

const AndroidNotificationChannel _defaultAndroidChannel =
    AndroidNotificationChannel(
      'gestscolaire_default',
      'Notifications',
      description: 'Notifications de l\'application',
      importance: Importance.high,
    );

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await _localNotifications.initialize(initSettings);

  final android = _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android != null) {
    await android.createNotificationChannel(_defaultAndroidChannel);
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final android = notification?.android;

  if (notification == null) return;

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _defaultAndroidChannel.id,
      _defaultAndroidChannel.name,
      channelDescription: _defaultAndroidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: android?.smallIcon,
    ),
  );

  await _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    notification.title,
    notification.body,
    details,
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Firebase
  await Firebase.initializeApp();

  // Notifications locales (pour afficher les notifs quand l'app est au premier plan)
  await _initLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Afficher une notification locale quand un message arrive en foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    try {
      await _showLocalNotification(message);
    } catch (_) {
      // ignore
    }
  });

  // Initialiser les services
  final apiService = ApiService();
  final authService = AuthService(apiService);
  apiService.attachAuthService(authService);
  await authService.init();

  // Initialiser FCM (best-effort)
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await apiService.post(
        '/parent/fcm/register/',
        data: {'token': token, 'platform': 'flutter'},
      );
    }

    messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      try {
        await apiService.post(
          '/parent/fcm/register/',
          data: {'token': newToken, 'platform': 'flutter'},
        );
      } catch (_) {
        // ignore
      }
    });
  } catch (_) {
    // ignore
  }

  runApp(MyApp(apiService: apiService, authService: authService));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final AuthService authService;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({Key? key, required this.apiService, required this.authService})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => apiService),
        Provider<AuthService>(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => ParentContextProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: AppConfig.appName,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.light, // TODO: Ajouter la gestion du mode sombre
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppRouter(),
        onGenerateRoute: (settings) {
          if (settings.name == '/reset-password') {
            final args = settings.arguments;
            if (args is Map<String, String>) {
              final email = args['email'];
              final token = args['token'];
              if (email != null && token != null) {
                return MaterialPageRoute(
                  builder: (_) =>
                      ResetPasswordScreen(email: email, token: token),
                );
              }
            }
          }
          return null;
        },
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) =>
              const MainShell(initialTab: ShellTab.dashboard),
          '/timetable': (context) =>
              const MainShell(initialTab: ShellTab.timetable),
          '/profile': (context) => const ParentProfileScreen(),
          '/notes': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.notes,
          ),
          '/homework': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.homework,
          ),
          '/bulletins': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.bulletins,
          ),
          '/notifications': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.notifications,
          ),
          '/scolarites': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.scolarites,
          ),
          '/absences': (context) => const MainShell(
            initialTab: ShellTab.modules,
            initialModule: ShellModuleKind.absences,
          ),
          '/select-establishment': (context) =>
              const SelectEstablishmentScreen(),
          '/select-child': (context) => const SelectChildScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Routeur principal de l'application
class AppRouter extends StatefulWidget {
  const AppRouter({Key? key}) : super(key: key);

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late Future<void> _initFuture;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Initialiser une seule fois au démarrage
    _initFuture = context.read<AuthProvider>().init();

    _handleInitialLink();
    _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingLink);
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleIncomingLink(uri);
      }
    } catch (_) {
      // ignore
    }
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme != 'gestscolaire') return;
    if (uri.host != 'reset-password') return;

    final email = uri.queryParameters['email'];
    final token = uri.queryParameters['token'];
    if (email == null || email.isEmpty || token == null || token.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MyApp.navigatorKey.currentState?.pushNamed(
        '/reset-password',
        arguments: {'email': email, 'token': token},
      );
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Pendant l'initialisation, afficher le splash screen
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Après l'initialisation, afficher le bon écran
        return Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.isAuthenticated &&
                authProvider.currentUser != null) {
              return const MainShell(initialTab: ShellTab.dashboard);
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}

/// Écran de chargement
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const Color _bgGreenDark = Color(0xFF001A12);
  static const Color _bgGreen = Color(0xFF00C853);
  static const Color _bgGreenGlow = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGreenDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.05,
            colors: [_bgGreenGlow, _bgGreen, _bgGreenDark],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x8800E676),
                          blurRadius: 28,
                          spreadRadius: 6,
                          offset: Offset(0, 0),
                        ),
                        BoxShadow(
                          color: Color(0x6600C853),
                          blurRadius: 60,
                          spreadRadius: 10,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xl),
                  Text(
                    AppConfig.appName,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    'Gestion scolaire simplifiée',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppTheme.xxxl),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
