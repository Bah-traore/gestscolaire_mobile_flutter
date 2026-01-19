import 'package:flutter/material.dart';

/// Extensions utiles
extension StringExtension on String {
  /// Vérifier si c'est une adresse email valide
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }
  
  /// Vérifier si c'est un numéro de téléphone valide
  bool get isValidPhone {
    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    return phoneRegex.hasMatch(replaceAll(RegExp(r'\s'), ''));
  }
  
  /// Capitaliser la première lettre
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
  
  /// Capitaliser chaque mot
  String get capitalizeWords {
    return split(' ')
        .map((word) => word.capitalize)
        .join(' ');
  }
  
  /// Obtenir les initiales
  String get initials {
    final parts = split(' ');
    if (parts.isEmpty) return '';
    
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  
  /// Vérifier si c'est vide ou null
  bool get isNullOrEmpty => isEmpty;
  
  /// Obtenir le texte tronqué
  String truncate(int length) {
    if (this.length <= length) return this;
    return '${substring(0, length)}...';
  }
  
  /// Supprimer les espaces inutiles
  String get cleanWhitespace {
    return trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

/// Extensions pour les nombres
extension NumExtension on num {
  /// Formater comme devise
  String toCurrency({String symbol = '\$', int decimals = 2}) {
    return '$symbol${toStringAsFixed(decimals)}';
  }
  
  /// Formater avec séparateurs de milliers
  String toFormattedString({int decimals = 0}) {
    final formatter = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    final stringValue = toStringAsFixed(decimals);
    return stringValue.replaceAllMapped(
      formatter,
      (match) => '${match.group(1)},',
    );
  }
  
  /// Vérifier si c'est positif
  bool get isPositive => this > 0;
  
  /// Vérifier si c'est négatif
  bool get isNegative => this < 0;
  
  /// Vérifier si c'est zéro
  bool get isZero => this == 0;
}

/// Extensions pour les listes
extension ListExtension<T> on List<T> {
  /// Vérifier si la liste est vide
  bool get isEmpty => length == 0;
  
  /// Vérifier si la liste n'est pas vide
  bool get isNotEmpty => length > 0;
  
  /// Obtenir le premier élément ou null
  T? get firstOrNull => isEmpty ? null : first;
  
  /// Obtenir le dernier élément ou null
  T? get lastOrNull => isEmpty ? null : last;
  
  /// Dupliquer la liste
  List<T> duplicate() => [...this];
  
  /// Mélanger la liste
  List<T> shuffle() {
    final list = duplicate();
    list.shuffle();
    return list;
  }
}

/// Extensions pour les dates
extension DateTimeExtension on DateTime {
  /// Vérifier si c'est aujourd'hui
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// Vérifier si c'est hier
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
  
  /// Vérifier si c'est demain
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }
  
  /// Obtenir la date formatée
  String toFormattedString({String format = 'dd/MM/yyyy'}) {
    // Format simple: dd/MM/yyyy, HH:mm, etc.
    final day = this.day.toString().padLeft(2, '0');
    final month = this.month.toString().padLeft(2, '0');
    final year = this.year;
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    
    return format
        .replaceAll('dd', day)
        .replaceAll('MM', month)
        .replaceAll('yyyy', year.toString())
        .replaceAll('HH', hour)
        .replaceAll('mm', minute);
  }
  
  /// Obtenir la différence en jours
  int daysDifference(DateTime other) {
    return difference(other).inDays;
  }
  
  /// Obtenir la différence en heures
  int hoursDifference(DateTime other) {
    return difference(other).inHours;
  }
  
  /// Obtenir la différence en minutes
  int minutesDifference(DateTime other) {
    return difference(other).inMinutes;
  }
}

/// Extensions pour BuildContext
extension BuildContextExtension on BuildContext {
  /// Obtenir la hauteur de l'écran
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// Obtenir la largeur de l'écran
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// Obtenir le padding du système
  EdgeInsets get systemPadding => MediaQuery.of(this).padding;
  
  /// Vérifier si l'écran est en mode portrait
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
  
  /// Vérifier si l'écran est en mode paysage
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  
  /// Vérifier si l'écran est petit
  bool get isSmallScreen => screenWidth < 600;
  
  /// Vérifier si l'écran est moyen
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 900;
  
  /// Vérifier si l'écran est grand
  bool get isLargeScreen => screenWidth >= 900;
  
  /// Afficher un SnackBar
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }
  
  /// Afficher un dialogue
  Future<T?> showCustomDialog<T>(
    Widget Function(BuildContext) builder, {
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
}

/// Extensions pour les couleurs
extension ColorExtension on Color {
  /// Obtenir une version plus claire
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness(
      (hsl.lightness + amount).clamp(0, 1),
    );
    return lightened.toColor();
  }
  
  /// Obtenir une version plus foncée
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness(
      (hsl.lightness - amount).clamp(0, 1),
    );
    return darkened.toColor();
  }
  
  /// Obtenir le code hexadécimal
  String toHex() {
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
