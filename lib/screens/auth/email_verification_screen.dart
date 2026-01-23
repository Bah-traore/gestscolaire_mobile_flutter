import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/extensions.dart';
import '../../utils/user_friendly_errors.dart';
import '../../widgets/custom_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email})
    : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post(
        '/auth/verify-email/',
        data: {
          'email': widget.email.trim(),
          'code': _codeController.text.trim(),
        },
      );

      if (!mounted) return;
      context.showSnackBar(
        'Email vérifié avec succès. Vous pouvez maintenant vous connecter.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(
        UserFriendlyErrors.from(e),
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth >= 600 ? AppTheme.xxl : AppTheme.lg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifier votre email'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppTheme.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppTheme.xl),
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 72,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Text(
                    'Confirmez votre adresse email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'Nous avons envoyé un code de vérification à :\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xxxl),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Code de vérification',
                        hintText: '6 chiffres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLength: 6,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Le code est requis';
                        if (v.length != 6) {
                          return 'Le code doit contenir 6 chiffres';
                        }
                        if (!RegExp(r'^\\d{6}$').hasMatch(v)) {
                          return 'Code invalide';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _verify(),
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  CustomButton(
                    label: 'Valider',
                    isLoading: _isLoading,
                    onPressed: () {
                      if (_isLoading) return;
                      _verify();
                    },
                  ),
                  const SizedBox(height: AppTheme.lg),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Modifier l\'adresse email',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
