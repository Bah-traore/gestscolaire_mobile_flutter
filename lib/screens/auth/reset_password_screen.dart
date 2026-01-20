import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmResetPasswordEmail(
      email: widget.email,
      token: widget.token,
      newPassword: _passwordController.text,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Erreur de réinitialisation.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe mis à jour. Vous pouvez vous connecter.'),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau mot de passe'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [AppTheme.shadowSmall],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Créer un nouveau mot de passe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    widget.email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomTextField(
                          label: 'Nouveau mot de passe',
                          controller: _passwordController,
                          obscureText: true,
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: AppTheme.md),
                        CustomTextField(
                          label: 'Confirmer le mot de passe',
                          controller: _confirmController,
                          obscureText: true,
                          validator: (v) => Validators.validateMatch(
                            v,
                            _passwordController.text,
                            fieldName: 'mots de passe',
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Mettre à jour',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
