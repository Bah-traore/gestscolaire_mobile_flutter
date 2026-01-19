import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/parent_context_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/modules_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Firebase
  await Firebase.initializeApp();

  // Initialiser les services
  final apiService = ApiService();
  final authService = AuthService(apiService);
  apiService.attachAuthService(authService);
  await authService.init();

  runApp(MyApp(apiService: apiService, authService: authService));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final AuthService authService;

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
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/timetable': (context) => const TimetableScreen(),
          '/notes': (context) => const ModulesScreen(kind: ModuleKind.notes),
          '/homework': (context) =>
              const ModulesScreen(kind: ModuleKind.homework),
          '/bulletins': (context) =>
              const ModulesScreen(kind: ModuleKind.bulletins),
          '/notifications': (context) =>
              const ModulesScreen(kind: ModuleKind.notifications),
          '/scolarites': (context) =>
              const ModulesScreen(kind: ModuleKind.scolarites),
          '/absences': (context) =>
              const ModulesScreen(kind: ModuleKind.absences),
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

  @override
  void initState() {
    super.initState();
    // Initialiser une seule fois au démarrage
    _initFuture = context.read<AuthProvider>().init();
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
              return const DashboardScreen();
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
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
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
                    boxShadow: const [AppTheme.shadowLarge],
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
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Gestion scolaire simplifiée',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.xxxl),
                const CircularProgressIndicator(color: AppTheme.primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
