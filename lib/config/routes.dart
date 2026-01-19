import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';

/// Configuration des routes de l'application
class AppRoutes {
  // Noms des routes
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String splash = '/';
  
  /// Générer les routes
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      dashboard: (context) => const DashboardScreen(),
    };
  }
  
  /// Naviguer vers une route
  static Future<dynamic> navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  /// Naviguer et remplacer
  static Future<dynamic> navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  /// Naviguer et supprimer tout
  static Future<dynamic> navigateAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }
  
  /// Revenir en arrière
  static void pop(BuildContext context, {dynamic result}) {
    Navigator.of(context).pop(result);
  }
}

/// Classe pour les arguments de navigation
class NavigationArguments {
  final Map<String, dynamic> data;
  
  NavigationArguments({required this.data});
  
  /// Obtenir une valeur
  T? get<T>(String key) {
    return data[key] as T?;
  }
  
  /// Vérifier si une clé existe
  bool contains(String key) {
    return data.containsKey(key);
  }
}
