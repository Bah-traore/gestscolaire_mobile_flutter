import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class FirebaseOtpService {
  static final FirebaseOtpService _instance = FirebaseOtpService._internal();
  factory FirebaseOtpService() => _instance;
  FirebaseOtpService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  String? _verificationId;

  String _mapPhoneAuthError(FirebaseAuthException e) {
    final rawMessage = (e.message ?? '').toUpperCase();
    if (rawMessage.contains('BILLING_NOT_ENABLED')) {
      return "La facturation n'est pas activée sur votre projet Firebase (BILLING_NOT_ENABLED). Activez un compte de facturation dans Google Cloud / Firebase ou utilisez des numéros de test.";
    }
    switch (e.code) {
      case 'operation-not-allowed':
        return "Cette opération n'est pas autorisée. Activez l'authentification par téléphone (Phone) dans Firebase Console.";
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez plus tard.";
      case 'quota-exceeded':
        return "Quota SMS dépassé. Réessayez plus tard.";
      case 'missing-client-identifier':
        return "Configuration Android invalide (SHA-1/SHA-256). Vérifiez l'app dans Firebase Console.";
      default:
        if (e.message != null &&
            e.message!.toUpperCase().contains('BILLING_NOT_ENABLED')) {
          return "La facturation n'est pas activée sur votre projet Firebase (BILLING_NOT_ENABLED). Activez un compte de facturation dans Google Cloud / Firebase ou utilisez des numéros de test.";
        }
        return e.message ??
            'Erreur lors de la vérification du numéro de téléphone.';
    }
  }

  /// Envoyer un OTP au numéro de téléphone
  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    try {
      _logger.i('Envoi OTP vers: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification sur Android
          _logger.i('Auto-verification réussie');
        },
        verificationFailed: (FirebaseAuthException e) {
          final friendly = _mapPhoneAuthError(e);
          _logger.e('Échec verification (${e.code}): $friendly');
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error': friendly,
              'code': e.code,
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _logger.i('OTP envoyé avec succès');
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'message': 'OTP envoyé avec succès',
              'verificationId': verificationId,
              'resendToken': resendToken,
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _logger.i('Timeout auto-retrieval');
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'message': 'OTP envoyé (timeout auto-retrieval)',
              'verificationId': verificationId,
            });
          }
        },
        forceResendingToken: forceResendingToken,
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => {
          'success': false,
          'error': "Délai dépassé lors de l'envoi de l'OTP.",
        },
      );
    } catch (e) {
      _logger.e('Erreur envoi OTP: $e');
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error':
              "Impossible d'envoyer le code pour le moment. Veuillez réessayer.",
        });
      }
      return await completer.future;
    }
  }

  /// Vérifier le code OTP et obtenir le token Firebase
  Future<Map<String, dynamic>> verifyOtp({
    required String otpCode,
    String? verificationId,
  }) async {
    try {
      _logger.i('Vérification OTP: $otpCode');

      final vid = verificationId ?? _verificationId;
      if (vid == null) {
        throw Exception('Aucun verificationId disponible');
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: otpCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Obtenir le token ID Firebase
        final String? idToken = await user.getIdToken();

        _logger.i('OTP vérifié avec succès pour: ${user.phoneNumber}');

        return {
          'success': true,
          'message': 'OTP vérifié avec succès',
          'user': {
            'uid': user.uid,
            'phoneNumber': user.phoneNumber,
            'idToken': idToken,
          },
        };
      } else {
        throw Exception('Utilisateur non trouvé après vérification');
      }
    } catch (e) {
      _logger.e('Erreur vérification OTP: $e');
      return {
        'success': false,
        'error': "Impossible de vérifier le code. Veuillez réessayer.",
      };
    }
  }

  /// Obtenir le token ID de l'utilisateur actuel
  Future<String?> getCurrentUserIdToken() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      _logger.e('Erreur récupération token: $e');
      return null;
    }
  }

  /// Vérifier si l'utilisateur est connecté
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _verificationId = null;
      _logger.i('Déconnexion Firebase réussie');
    } catch (e) {
      _logger.e('Erreur déconnexion: $e');
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Réinitialiser le verificationId
  void resetVerificationId() {
    _verificationId = null;
  }
}
