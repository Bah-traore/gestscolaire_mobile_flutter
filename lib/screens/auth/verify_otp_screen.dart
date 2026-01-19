import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_otp_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart' as custom;

class VerifyOtpScreen extends StatefulWidget {
  final String phone;
  final int userId;

  const VerifyOtpScreen({Key? key, required this.phone, required this.userId})
    : super(key: key);

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Veuillez entrer un code à 6 chiffres';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firebaseOtpService = FirebaseOtpService();

      // 1. Vérifier l'OTP avec Firebase
      final firebaseResult = await firebaseOtpService.verifyOtp(
        otpCode: _otpController.text,
      );

      if (!firebaseResult['success']) {
        throw Exception(firebaseResult['error']);
      }

      // 2. Envoyer le token Firebase à notre backend pour finaliser l'inscription
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.verifyPhoneOtp(
        phone: widget.phone,
        otp: _otpController.text,
        userId: widget.userId,
        firebaseToken: firebaseResult['user']['idToken'],
      );

      // 3. Si succès, naviguer vers l'écran principal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Numéro vérifié avec succès!'),
            backgroundColor: Colors.green,
          ),
        );

        // Naviguer vers l'écran principal (dashboard)
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifier le téléphone'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Icône et titre
              Icon(Icons.verified_user, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 24),

              Text(
                'Vérifier votre numéro',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Un code de vérification a été envoyé à ${widget.phone}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Messages d'erreur
              if (_errorMessage != null) ...[
                custom.ErrorWidget(
                  message: _errorMessage!,
                  onRetry: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),
              ],

              // Champ OTP
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Code OTP',
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  counterText: '',
                ),
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Bouton de vérification
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const LoadingWidget()
                      : const Text(
                          'Vérifier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Lien pour renvoyer le code
              Center(
                child: TextButton(
                  onPressed: _resendCountdown > 0
                      ? null
                      : () {
                          // TODO: Implémenter le renvoi du code OTP
                          setState(() {
                            _resendCountdown = 60;
                          });
                        },
                  child: Text(
                    _resendCountdown > 0
                        ? 'Renvoyer le code dans $_resendCountdown s'
                        : 'Renvoyer le code',
                    style: TextStyle(
                      color: _resendCountdown > 0
                          ? Colors.grey[400]
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
