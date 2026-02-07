import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../services/update_checker.dart';

class ParentProfileScreen extends StatelessWidget {
  const ParentProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Widget _glassCard(Widget child) {
    final glowA = const Color(0xFF00E676);
    final glowB = const Color(0xFF00BFA5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: glowA.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          AppTheme.shadowSmall,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceColor.withOpacity(0.96),
                  AppTheme.surfaceColor.withOpacity(0.84),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: glowB.withOpacity(0.20), width: 1.1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePhoneDialog(
    BuildContext context,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppTheme.xl),
          child: _glassCard(
            Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modifier le téléphone',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  CustomTextField(
                    label: 'Téléphone',
                    hint: '+223XXXXXXXX',
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    validator: Validators.validatePhone,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            final provider = ctx.read<AuthProvider>();
                            final resp = await provider.updatePhone(
                              phone: controller.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            if (resp == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ?? 'Erreur de mise à jour.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.of(ctx).pop(resp);
                          },
                          child: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (res == null) return;

    final remaining = res['remaining_changes'];
    final year = res['academic_year'];
    final msg = (remaining is num && year != null)
        ? 'Téléphone mis à jour. Restant: ${remaining.toInt()}/3 • $year'
        : 'Téléphone mis à jour.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppTheme.xl),
          child: _glassCard(
            Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changer le mot de passe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  CustomTextField(
                    label: 'Ancien mot de passe',
                    controller: oldCtrl,
                    obscureText: true,
                    validator: (v) => Validators.validateRequired(
                      v,
                      fieldName: 'Ancien mot de passe',
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  CustomTextField(
                    label: 'Nouveau mot de passe',
                    controller: newCtrl,
                    obscureText: true,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: AppTheme.md),
                  CustomTextField(
                    label: 'Confirmer le nouveau mot de passe',
                    controller: confirmCtrl,
                    obscureText: true,
                    validator: (v) => Validators.validateMatch(
                      v,
                      newCtrl.text,
                      fieldName: 'mots de passe',
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            final provider = ctx.read<AuthProvider>();
                            final ok = await provider.changePassword(
                              oldPassword: oldCtrl.text,
                              newPassword: newCtrl.text,
                              confirmPassword: confirmCtrl.text,
                            );
                            if (!ctx.mounted) return;
                            if (!ok) {
                              final err =
                                  provider.error ?? 'Erreur de mise à jour.';

                              // Cas compte Google: pas d'ancien mot de passe
                              final lower = err.toLowerCase();
                              final bool shouldOfferSet =
                                  lower.contains('ancien') &&
                                  lower.contains('incorrect');
                              if (shouldOfferSet) {
                                final wants = await showDialog<bool>(
                                  context: ctx,
                                  builder: (c2) => AlertDialog(
                                    title: const Text(
                                      'Définir un mot de passe',
                                    ),
                                    content: const Text(
                                      'Votre compte semble ne pas avoir de mot de passe (connexion Google). Voulez-vous définir un mot de passe maintenant ?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(c2).pop(false),
                                        child: const Text('Annuler'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(c2).pop(true),
                                        child: const Text('Définir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (!ctx.mounted) return;
                                if (wants == true) {
                                  final okSet = await provider.setPassword(
                                    newPassword: newCtrl.text,
                                    confirmPassword: confirmCtrl.text,
                                  );
                                  if (!ctx.mounted) return;
                                  if (okSet) {
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mot de passe défini.'),
                                      ),
                                    );
                                    return;
                                  }
                                }
                              }

                              ScaffoldMessenger.of(
                                ctx,
                              ).showSnackBar(SnackBar(content: Text(err)));
                              return;
                            }
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mot de passe mis à jour.'),
                              ),
                            );
                          },
                          child: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final name = user?.fullName ?? 'Parent';
    final email = (user?.email ?? '').trim();
    final phone = (user?.phone ?? '').trim();

    final glowA = const Color(0xFF00E676);
    final glowB = const Color(0xFF00BFA5);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.lg),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            child: Stack(
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        Color.lerp(AppTheme.primaryColor, glowB, 0.40)!,
                        Color.lerp(AppTheme.primaryColor, Colors.black, 0.22)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glowA.withOpacity(0.55), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -60,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glowB.withOpacity(0.45), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [glowA, glowB],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glowA.withOpacity(0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.4),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                (user?.initials ?? 'P'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.xs),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
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
          const SizedBox(height: AppTheme.xl),

          _glassCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sécurité',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      color: glowA.withOpacity(0.10),
                      border: Border.all(color: glowA.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.lock_outline, size: 20),
                  ),
                  title: const Text('Changer le mot de passe'),
                  subtitle: const Text('Mettre à jour votre mot de passe.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: auth.isLoading
                      ? null
                      : () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      color: Colors.orange.withOpacity(0.10),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text('Vérifier les mises à jour'),
                  subtitle: const Text('Tester le système de mise à jour.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => UpdateChecker.testUpdateCheck(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      color: glowB.withOpacity(0.10),
                      border: Border.all(color: glowB.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.phone_iphone, size: 20),
                  ),
                  title: const Text('Modifier le téléphone'),
                  subtitle: const Text(
                    'Maximum 3 modifications / année scolaire.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: auth.isLoading
                      ? null
                      : () => _showChangePhoneDialog(context, phone),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.xl),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: auth.isLoading ? null : () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
