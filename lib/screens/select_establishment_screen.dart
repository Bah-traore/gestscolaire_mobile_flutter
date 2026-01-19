import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/establishments_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;
import '../utils/user_friendly_errors.dart';

class SelectEstablishmentScreen extends StatefulWidget {
  const SelectEstablishmentScreen({super.key});

  @override
  State<SelectEstablishmentScreen> createState() =>
      _SelectEstablishmentScreenState();
}

class _SelectEstablishmentScreenState extends State<SelectEstablishmentScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _establishments = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final auth = context.read<AuthProvider>();
      final service = EstablishmentsService(api);

      final identifier =
          ((auth.currentUser?.email ?? '').toString().trim().isNotEmpty)
          ? (auth.currentUser?.email ?? '').toString().trim()
          : (auth.currentUser?.phone ?? '').toString().trim();
      if (identifier.isEmpty) {
        throw Exception('Identifiant (email ou téléphone) requis');
      }

      final items = await service.discover(identifier: identifier);
      setState(() {
        _establishments = items;
      });
    } on DioException catch (e) {
      setState(() {
        _error = UserFriendlyErrors.fromDio(e);
      });
    } catch (e) {
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _select(Map<String, dynamic> est) async {
    final subdomain = (est['id'] ?? '').toString();
    final name = (est['name'] ?? '').toString();
    if (subdomain.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final service = EstablishmentsService(api);

      final resp = await service.switchEstablishment(
        establishmentId: subdomain,
      );
      final estData = resp['establishment'];
      if (estData is! Map) {
        throw Exception('Réponse établissement invalide');
      }

      final tenantIdRaw = estData['tenant_id'];
      final tenantId = tenantIdRaw is int
          ? tenantIdRaw
          : int.tryParse((tenantIdRaw ?? '').toString());
      if (tenantId == null) {
        throw Exception('tenant_id manquant');
      }

      final ctx = context.read<ParentContextProvider>();
      ctx.setEstablishment(
        SelectedEstablishment(
          subdomain: subdomain,
          tenantId: tenantId,
          name: (estData['name'] ?? name).toString(),
          logo: estData['logo']?.toString(),
          city: estData['city']?.toString(),
        ),
      );

      // switch-establishment renvoie de nouveaux tokens
      final accessToken = resp['access_token'];
      final refreshToken = resp['refresh_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        final authService = context.read<AuthService>();
        await authService.setTokens(
          accessToken: accessToken,
          refreshToken: refreshToken is String ? refreshToken : null,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/select-child');
    } catch (e) {
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Choisir une école')),
      body: _loading
          ? const Center(child: LoadingWidget())
          : _error != null
          ? Center(
              child: custom.ErrorWidget(message: _error!, onRetry: _load),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppTheme.lg),
              itemCount: _establishments.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
              itemBuilder: (context, index) {
                final est = _establishments[index];
                final name = (est['name'] ?? '').toString();
                final city = (est['city'] ?? '').toString();
                final count = est['children_count'];

                return InkWell(
                  onTap: () => _select(est),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: const [AppTheme.shadowSmall],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'Établissement',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (city.isNotEmpty)
                                Text(
                                  city,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (count != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.md,
                              vertical: AppTheme.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
