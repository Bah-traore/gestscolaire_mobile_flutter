import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/user_friendly_errors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/register_screen.dart';

/// Écran de connexion
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<String?> _askPhoneNumber(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vérifier votre téléphone'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '+22376123456',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final response = await authService.signInWithGoogle();

      // Flow onboarding
      if (response.requiresOnboarding == true) {
        final userId = response.user?.id;
        if (userId == null) {
          throw Exception('user_id manquant pour onboarding');
        }

        final phone = await _askPhoneNumber(context);
        if (phone == null || phone.isEmpty) {
          throw Exception('Numéro de téléphone requis');
        }

        await authService.verifyPhoneOtp(
          phone: phone,
          otp: '',
          userId: userId,
          firebaseToken: null,
        );

        authProvider.clearError();
        await authProvider.init();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }

      // Connexion directe (tokens présents)
      authProvider.clearError();
      await authProvider.init();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UserFriendlyErrors.from(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.xxxl),

              // Logo et titre
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: AppTheme.lg),
                    Text(
                      'GestEcole',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      'Gestion scolaire simplifiée',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.xxxl),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email
                    EmailField(
                      controller: _emailController,
                      label: 'Adresse email',
                      hint: 'exemple@ecole.com',
                    ),

                    const SizedBox(height: AppTheme.lg),

                    // Mot de passe
                    PasswordField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      hint: 'Entrez votre mot de passe',
                    ),

                    const SizedBox(height: AppTheme.md),

                    // Lien "Mot de passe oublié"
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //   child: TextButton(
                    //     onPressed: () {
                    //       // TODO: Naviguer vers l'écran de réinitialisation
                    //     },
                    //     child: Text(
                    //       'Mot de passe oublié?',
                    //       style: Theme.of(context).textTheme.bodyMedium
                    //           ?.copyWith(
                    //             color: AppTheme.primaryColor,
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //     ),
                    //   ),
                    // ),

                    // const SizedBox(height: AppTheme.xl),

                    // Bouton de connexion
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        return CustomButton(
                          label: 'Se connecter',
                          isLoading: authProvider.isLoading,
                          onPressed: () => _handleLogin(context, authProvider),
                        );
                      },
                    ),

                    const SizedBox(height: AppTheme.lg),

                    // Message d'erreur
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        if (authProvider.error != null) {
                          return Container(
                            padding: const EdgeInsets.all(AppTheme.md),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Text(
                                    authProvider.error!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.errorColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.xxxl),

              // Bouton de connexion Google
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _handleGoogleSignIn(context),
                  icon: const Icon(Icons.g_mobiledata, size: 20),
                  label: const Text(
                    'Se connecter avec Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.xxxl),

              // Lien mot de passe oublié
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Mot de passe oublié?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.md),

              // Lien d'inscription
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'S\'inscrire',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gérer la connexion
  Future<void> _handleLogin(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }
}
