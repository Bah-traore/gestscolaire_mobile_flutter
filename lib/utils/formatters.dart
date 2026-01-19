import 'package:intl/intl.dart';

/// Utilitaires de formatage
class AppFormatters {
  /// Formater une date
  static String formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    try {
      final formatter = DateFormat(format, 'fr_FR');
      return formatter.format(date);
    } catch (e) {
      return date.toString();
    }
  }
  
  /// Formater une heure
  static String formatTime(DateTime time, {String format = 'HH:mm'}) {
    try {
      final formatter = DateFormat(format, 'fr_FR');
      return formatter.format(time);
    } catch (e) {
      return time.toString();
    }
  }
  
  /// Formater une date et heure
  static String formatDateTime(DateTime dateTime, {String format = 'dd/MM/yyyy HH:mm'}) {
    try {
      final formatter = DateFormat(format, 'fr_FR');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTime.toString();
    }
  }
  
  /// Formater une devise
  static String formatCurrency(double amount, {String symbol = 'XOF'}) {
    try {
      final formatter = NumberFormat.currency(
        locale: 'fr_FR',
        symbol: symbol,
        decimalDigits: 2,
      );
      return formatter.format(amount);
    } catch (e) {
      return '$amount $symbol';
    }
  }
  
  /// Formater un nombre
  static String formatNumber(num number, {int decimals = 2}) {
    try {
      final formatter = NumberFormat('###,##0.${'0' * decimals}', 'fr_FR');
      return formatter.format(number);
    } catch (e) {
      return number.toString();
    }
  }
  
  /// Formater un pourcentage
  static String formatPercentage(double value, {int decimals = 2}) {
    try {
      final formatter = NumberFormat.percentPattern('fr_FR');
      return formatter.format(value);
    } catch (e) {
      return '${(value * 100).toStringAsFixed(decimals)}%';
    }
  }
  
  /// Formater un numéro de téléphone
  static String formatPhoneNumber(String phone) {
    // Supprimer tous les caractères non numériques
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.isEmpty) return phone;
    
    // Format: +223 XX XX XX XX
    if (cleaned.length >= 8) {
      return '+223 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)}';
    }
    
    return phone;
  }
  
  /// Formater un email
  static String formatEmail(String email) {
    return email.toLowerCase().trim();
  }
  
  /// Obtenir la date relative (ex: "Il y a 2 heures")
  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return 'Il y a ${(difference.inDays / 365).floor()} an(s)';
    } else if (difference.inDays > 30) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour(s)';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure(s)';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute(s)';
    } else {
      return 'À l\'instant';
    }
  }
  
  /// Formater la taille d'un fichier
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int index = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[index]}';
  }
  
  /// Capitaliser la première lettre
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }
  
  /// Capitaliser chaque mot
  static String capitalizeWords(String text) {
    return text
        .split(' ')
        .map((word) => capitalize(word))
        .join(' ');
  }
  
  /// Obtenir les initiales
  static String getInitials(String fullName) {
    final parts = fullName.split(' ');
    if (parts.isEmpty) return '';
    
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  
  /// Tronquer le texte
  static String truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }
  
  /// Masquer l'email (ex: t***@example.com)
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final name = parts[0];
    final domain = parts[1];
    
    if (name.length <= 1) return email;
    
    final masked = '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@$domain';
  }
  
  /// Masquer le numéro de téléphone (ex: +223 XX XX XX 1234)
  static String maskPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.length < 4) return phone;
    
    final masked = '${'*' * (cleaned.length - 4)}${cleaned.substring(cleaned.length - 4)}';
    return '+223 $masked';
  }
}
