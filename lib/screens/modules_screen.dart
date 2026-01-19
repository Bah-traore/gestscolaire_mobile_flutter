import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/children_service.dart';
import '../services/establishments_service.dart';
import '../services/modules_service.dart';
import '../utils/user_friendly_errors.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;

enum ModuleKind {
  notes,
  homework,
  bulletins,
  notifications,
  scolarites,
  absences,
}

class ModulesScreen extends StatefulWidget {
  final ModuleKind kind;

  const ModulesScreen({super.key, required this.kind});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _data;

  List<Map<String, dynamic>> _availableEstablishments = const [];
  List<Map<String, dynamic>> _availableChildren = const [];
  bool _loadingSelector = false;

  bool _initialized = false;

  int? _selectedBulletinId;
  List<Map<String, dynamic>> _availableBulletinExams = const [];

  String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = DateTime(dt.year, dt.month, dt.day);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildAbsencesBody(BuildContext context) {
    final raw = _data?['absences'];
    final absences = (raw is List)
        ? raw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final stats = (_data?['statistics'] is Map)
        ? Map<String, dynamic>.from(_data!['statistics'] as Map)
        : const <String, dynamic>{};

    final filters = (_data?['filters'] is Map)
        ? Map<String, dynamic>.from(_data!['filters'] as Map)
        : const <String, dynamic>{};
    final currentStatus = filters['status']?.toString();

    final total = stats['total_absences'];
    final justified = stats['justified'];
    final pending = stats['pending'];
    final unjustified = stats['unjustified'];

    Color statusColor(String? s) {
      final v = (s ?? '').toUpperCase();
      if (v == 'JUSTIFIE') return Colors.green;
      if (v == 'EN_ATTENTE') return Colors.orange;
      if (v == 'NON_JUSTIFIE') return Colors.red;
      return AppTheme.primaryColor;
    }

    String statusLabel(String? s) {
      final v = (s ?? '').toUpperCase();
      if (v == 'JUSTIFIE') return 'Justifiées';
      if (v == 'EN_ATTENTE') return 'En attente';
      if (v == 'NON_JUSTIFIE') return 'Non justifiées';
      return 'Toutes';
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Total',
                      value: total?.toString() ?? '-',
                      icon: Icons.event_busy,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'En attente',
                      value: pending?.toString() ?? '-',
                      icon: Icons.hourglass_empty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Justifiées',
                      value: justified?.toString() ?? '-',
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Non justifiées',
                      value: unjustified?.toString() ?? '-',
                      icon: Icons.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Filtrer par statut',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: currentStatus,
              hint: const Text('Toutes'),
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem(value: null, child: Text('Toutes')),
                DropdownMenuItem(value: 'JUSTIFIE', child: Text('Justifiées')),
                DropdownMenuItem(
                  value: 'EN_ATTENTE',
                  child: Text('En attente'),
                ),
                DropdownMenuItem(
                  value: 'NON_JUSTIFIE',
                  child: Text('Non justifiées'),
                ),
              ],
              onChanged: _loading
                  ? null
                  : (value) async {
                      // Recharger avec filtre côté backend via query param status
                      await _reloadWithExtraParams({'status': value});
                    },
            ),
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        if (absences.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Icon(Icons.info_outline, size: 18),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aucune absence',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.sm),
                      Text(
                        'Aucune absence n\'a été enregistrée pour l\'élève sur la période sélectionnée.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...absences.map((a) {
            final date = _formatDate(a['date']?.toString());
            final matiere = a['matiere']?.toString() ?? '';
            final motif = a['motif']?.toString() ?? '';
            final s = a['status']?.toString();
            final sLabel = a['status_label']?.toString() ?? statusLabel(s);
            final color = statusColor(s);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.sm),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.event_busy, size: 18),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          date.isNotEmpty ? date : 'Absence',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.md,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Text(
                          sLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (matiere.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      matiere,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (motif.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    Text(motif, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _reloadWithExtraParams(Map<String, dynamic> extra) async {
    final ctx = context.read<ParentContextProvider>();
    final eleveId = ctx.child?.id;
    if (eleveId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final resp = await api.get<Map<String, dynamic>>(
        '/parent/absences/',
        queryParameters: {
          'eleve_id': eleveId,
          if (ctx.academicYear != null) 'annee': ctx.academicYear,
          ...extra,
        },
      );

      if (!mounted) return;
      setState(() {
        _data = resp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildScolaritesBody(BuildContext context) {
    final total = _data?['total_amount'];
    final paid = _data?['paid_amount'];
    final remaining = _data?['remaining_amount'];
    final progress = _data?['progress_percent'];

    final periodePaiement = _data?['periode_paiement'];
    final periodeLabel = (periodePaiement is Map)
        ? (periodePaiement['nom']?.toString() ??
              periodePaiement['periode_scolaire']?.toString() ??
              '')
        : '';

    final tranchesRaw = _data?['tranches'];
    final tranches = (tranchesRaw is List)
        ? tranchesRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final paymentsRaw = _data?['payments'];
    final payments = (paymentsRaw is List)
        ? paymentsRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final hasAny = tranches.isNotEmpty || payments.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Text(
          'Aucune donnée de scolarité.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    String money(dynamic v) {
      if (v == null) return '-';
      if (v is num) {
        final n = v.toDouble();
        final s = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
        return '$s F';
      }
      return '${v.toString()} F';
    }

    final progressValue = (progress is num)
        ? (progress.toDouble() / 100.0)
        : double.tryParse(progress?.toString() ?? '') != null
        ? (double.parse(progress.toString()) / 100.0)
        : 0.0;
    final clamped = progressValue.clamp(0.0, 1.0);

    Color statusColor(String? s) {
      final v = (s ?? '').toLowerCase();
      if (v.contains('paye') || v.contains('paid') || v.contains('valide')) {
        return Colors.green;
      }
      if (v.contains('attente') || v.contains('pending')) {
        return Colors.orange;
      }
      if (v.contains('retard') ||
          v.contains('overdue') ||
          v.contains('impaye')) {
        return Colors.red;
      }
      return AppTheme.primaryColor;
    }

    final remainingNum = (remaining is num)
        ? remaining.toDouble()
        : double.tryParse(remaining?.toString() ?? '');
    final totalNum = (total is num)
        ? total.toDouble()
        : double.tryParse(total?.toString() ?? '');
    final paidNum = (paid is num)
        ? paid.toDouble()
        : double.tryParse(paid?.toString() ?? '');
    final bool fullyPaid =
        remainingNum != null && remainingNum <= 0.0001 && (totalNum ?? 0) > 0;

    final progressColor = fullyPaid
        ? Colors.green
        : (clamped >= 0.7
              ? Colors.green
              : (clamped >= 0.4 ? Colors.orange : Colors.red));

    return ListView(
      padding: const EdgeInsets.all(AppTheme.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: const Icon(Icons.receipt_long, size: 18),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Text(
                      'Récapitulatif',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (fullyPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        'Soldé',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              if (periodeLabel.trim().isNotEmpty) ...[
                const SizedBox(height: AppTheme.sm),
                Text(
                  periodeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppTheme.md),
              Row(
                children: [
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Total',
                      value: money(total),
                      icon: Icons.payments,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Payé',
                      value: money(paid),
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _kpiTile(
                      context,
                      label: 'Reste',
                      value: money(remaining),
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: clamped,
                  backgroundColor: AppTheme.borderColor.withOpacity(0.35),
                  color: progressColor,
                ),
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                'Progression: ${(clamped * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (paidNum != null && totalNum != null) ...[
                const SizedBox(height: AppTheme.sm),
                Text(
                  '${money(paidNum)} / ${money(totalNum)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        if (tranches.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    'Tranches',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${tranches.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),
          ...tranches.map((t) {
            final name = t['nom']?.toString() ?? 'Tranche';
            final echeance = _formatDate(t['date_echeance']?.toString());
            final montant = money(t['montant']);
            final montantPaye = money(t['montant_paye']);
            final statut = t['statut']?.toString() ?? '';
            final prog = t['progression'];
            final pv = (prog is num)
                ? (prog.toDouble() / 100.0)
                : double.tryParse(prog?.toString() ?? '') != null
                ? (double.parse(prog.toString()) / 100.0)
                : null;
            final cl = pv == null ? null : pv.clamp(0.0, 1.0);
            final color = statusColor(statut);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.sm),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        child: const Icon(Icons.payments_outlined, size: 18),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (statut.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.md,
                            vertical: AppTheme.sm,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(
                            statut,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  if (echeance.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      'Échéance: $echeance',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'Payé: $montantPaye / $montant',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (cl != null) ...[
                    const SizedBox(height: AppTheme.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: cl,
                        backgroundColor: AppTheme.borderColor.withOpacity(0.35),
                        color: color,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      'Progression: ${(cl * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: AppTheme.lg),
        ],

        if (payments.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    'Paiements récents',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${payments.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),
          ...payments.take(20).map((p) {
            final amount = money(p['montant_paye']);
            final date = _formatDate(p['date_paiement']?.toString());
            final mode = p['mode_paiement']?.toString() ?? '';
            final statut = p['statut']?.toString() ?? '';
            final trancheId = p['tranche_id']?.toString() ?? '';
            final color = statusColor(statut);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sm),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: const Icon(Icons.receipt, size: 18),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          amount,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          [
                            if (date.isNotEmpty) date,
                            if (mode.isNotEmpty) mode,
                            if (trancheId.isNotEmpty) 'Tranche $trancheId',
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (statut.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.sm,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Text(
                        statut,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _reloadBulletinById(int? bulletinId) async {
    if (bulletinId == null) return;
    setState(() {
      _selectedBulletinId = bulletinId;
    });

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final service = ModulesService(api);
      final ctx = context.read<ParentContextProvider>();

      final hasEstablishment = ctx.establishment != null;
      final eleveId = ctx.child?.id;
      if (!hasEstablishment) {
        throw Exception('Veuillez sélectionner une école');
      }
      if (eleveId == null) {
        throw Exception('Veuillez sélectionner un enfant');
      }

      Future<Map<String, dynamic>> run() {
        return service.fetchBulletins(
          eleveId: eleveId,
          annee: ctx.academicYear,
          examenId: bulletinId,
        );
      }

      Map<String, dynamic> resp;
      try {
        resp = await run();
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (!refreshed) {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
          resp = await run();
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final raw = resp['examens_disponibles'];
      final list = (raw is List)
          ? raw
                .whereType<Map>()
                .map((e) {
                  return e.map((k, v) => MapEntry(k.toString(), v));
                })
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final selected = resp['selected_examen_id'];
      setState(() {
        _data = resp;
        _availableBulletinExams = list;
        _selectedBulletinId = (selected is num)
            ? selected.toInt()
            : int.tryParse(selected?.toString() ?? '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildBulletinsBody(BuildContext context) {
    final bulletinsRaw = _data?['bulletins'];
    final bulletins = (bulletinsRaw is List)
        ? bulletinsRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final noteMax = _data?['note_max'];

    final examItems = _availableBulletinExams;
    final currentId = _selectedBulletinId;

    final Map<String, dynamic>? current = bulletins.isNotEmpty
        ? bulletins.first
        : null;
    final Map<String, dynamic>? exam = (current?['examen'] is Map)
        ? Map<String, dynamic>.from(current!['examen'] as Map)
        : null;
    final Map<String, dynamic>? periode = (current?['periode'] is Map)
        ? Map<String, dynamic>.from(current!['periode'] as Map)
        : null;
    final moyenne = current?['moyenne_generale'];
    final classement = current?['classement'];
    final mention = current?['mention'];

    final matieresRaw = current?['matieres'];
    final matieres = (matieresRaw is List)
        ? matieresRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final topMatiere = (current?['top_matiere'] is Map)
        ? Map<String, dynamic>.from(current!['top_matiere'] as Map)
        : null;
    final bottomMatiere = (current?['bottom_matiere'] is Map)
        ? Map<String, dynamic>.from(current!['bottom_matiere'] as Map)
        : null;
    final successRate = current?['success_rate_percent'];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.lg),
      children: [
        if (examItems.isNotEmpty)
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Examen / Bulletin',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: currentId,
                items: examItems
                    .map((e) {
                      final id = (e['id'] is num)
                          ? (e['id'] as num).toInt()
                          : int.tryParse(e['id']?.toString() ?? '');
                      final examen = e['examen']?.toString() ?? '';
                      final per = e['periode']?.toString() ?? '';
                      final date = _formatDate(e['date_examen']?.toString());
                      final label = [
                        if (examen.isNotEmpty) examen,
                        if (per.isNotEmpty) per,
                        if (date.isNotEmpty) date,
                      ].join(' • ');
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(label.isNotEmpty ? label : 'Bulletin'),
                      );
                    })
                    .toList(growable: false),
                onChanged: _loading
                    ? null
                    : (value) async {
                        if (value == null || value == currentId) return;
                        await _reloadBulletinById(value);
                      },
              ),
            ),
          ),
        if (examItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              'Aucun examen disponible pour cet élève sur la période sélectionnée.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppTheme.lg),

        if (current == null)
          Center(
            child: Text(
              'Aucun bulletin.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        exam?['nom']?.toString() ?? 'Bulletin',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (mention != null && mention.toString().trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.md,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        child: Text(
                          mention.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  [
                        periode?['nom']?.toString(),
                        if (exam != null) _formatDate(exam['date']?.toString()),
                      ]
                      .whereType<String>()
                      .where((s) => s.trim().isNotEmpty)
                      .join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.md),
                Row(
                  children: [
                    Expanded(
                      child: _kpiTile(
                        context,
                        label: 'Moyenne',
                        value: moyenne == null
                            ? '-'
                            : _formatNoteValue(moyenne, scale: noteMax),
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: _kpiTile(
                        context,
                        label: 'Classement',
                        value: classement?.toString() ?? '-',
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: _kpiTile(
                        context,
                        label: 'Réussite',
                        value: successRate == null
                            ? '-'
                            : '${successRate.toString()}%',
                      ),
                    ),
                  ],
                ),

                if (topMatiere != null || bottomMatiere != null) ...[
                  const SizedBox(height: AppTheme.lg),
                  Row(
                    children: [
                      if (topMatiere != null)
                        Expanded(
                          child: _highlightTile(
                            context,
                            title: 'Meilleure matière',
                            subject: topMatiere['nom']?.toString() ?? '-',
                            value: _formatNoteValue(
                              topMatiere['note'],
                              scale: noteMax,
                            ),
                            color: Colors.green,
                          ),
                        ),
                      if (topMatiere != null && bottomMatiere != null)
                        const SizedBox(width: AppTheme.md),
                      if (bottomMatiere != null)
                        Expanded(
                          child: _highlightTile(
                            context,
                            title: 'À améliorer',
                            subject: bottomMatiere['nom']?.toString() ?? '-',
                            value: _formatNoteValue(
                              bottomMatiere['note'],
                              scale: noteMax,
                            ),
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.lg),

          if (matieres.isNotEmpty)
            Text(
              'Détails par matière',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: AppTheme.md),
          ...matieres.map((m) {
            final matiere = m['matiere']?.toString() ?? 'Matière';
            final note = m['note'];
            final max = m['note_max'] ?? noteMax;
            final coef = m['coefficient'];
            final progress = m['progress_percent'];
            final valueLabel = _formatNoteValue(note, scale: max);
            final coefLabel = (coef == null)
                ? ''
                : (coef is num && coef % 1 == 0)
                ? coef.toInt().toString()
                : coef.toString();

            final progressValue = (progress is num)
                ? (progress.toDouble() / 100.0)
                : double.tryParse(progress?.toString() ?? '') != null
                ? (double.parse(progress.toString()) / 100.0)
                : null;
            final clamped = progressValue == null
                ? null
                : progressValue.clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matiere,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (coefLabel.isNotEmpty) ...[
                              const SizedBox(height: AppTheme.sm),
                              Text(
                                'Coef $coefLabel',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.md,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        child: Text(
                          valueLabel.isNotEmpty ? valueLabel : '-',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  if (clamped != null) ...[
                    const SizedBox(height: AppTheme.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: clamped,
                        backgroundColor: AppTheme.borderColor.withOpacity(0.35),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _kpiTile(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _highlightTile(
    BuildContext context, {
    required String title,
    required String subject,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTheme.sm),
          Text(subject, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppTheme.sm),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatNoteValue(dynamic value, {dynamic scale}) {
    if (value == null) return '';
    String v;
    if (value is num) {
      v = value % 1 == 0 ? value.toInt().toString() : value.toString();
    } else {
      v = value.toString();
    }
    final s = (scale is num)
        ? (scale % 1 == 0 ? scale.toInt().toString() : scale.toString())
        : (scale?.toString());
    if (s == null || s.trim().isEmpty) return v;
    return '$v/$s';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  String get _title {
    switch (widget.kind) {
      case ModuleKind.notes:
        return 'Notes';
      case ModuleKind.homework:
        return 'Devoirs';
      case ModuleKind.bulletins:
        return 'Bulletins';
      case ModuleKind.notifications:
        return 'Notifications';
      case ModuleKind.scolarites:
        return 'Scolarités';
      case ModuleKind.absences:
        return 'Absences';
    }
  }

  Future<void> _bootstrap() async {
    if (_initialized) return;
    _initialized = true;
    await _loadSelectorData();
    await _load();
  }

  Future<void> _loadSelectorData() async {
    if (!mounted) return;
    setState(() {
      _loadingSelector = true;
    });

    try {
      final api = context.read<ApiService>();
      final establishmentsService = EstablishmentsService(api);
      final childrenService = ChildrenService(api);

      final auth = context.read<AuthProvider>();
      final identifier = auth.currentUser?.email ?? auth.currentUser?.phone;
      if (identifier == null || identifier.trim().isEmpty) {
        setState(() {
          _availableEstablishments = const [];
          _availableChildren = const [];
        });
        return;
      }

      final establishments = await establishmentsService.discover(
        identifier: identifier,
      );

      final ctx = context.read<ParentContextProvider>();
      final selectedSubdomain = ctx.establishment?.subdomain;

      Map<String, dynamic>? selectedEstablishmentRaw;
      if (selectedSubdomain != null) {
        final matches = establishments
            .where((e) => (e['id']?.toString() ?? '') == selectedSubdomain)
            .toList(growable: false);
        if (matches.isNotEmpty) {
          selectedEstablishmentRaw = matches.first;
        }
      }

      List<Map<String, dynamic>> children = const [];
      if (selectedEstablishmentRaw != null) {
        children = await childrenService.fetchChildren(
          establishmentId: selectedEstablishmentRaw['id']?.toString() ?? '',
          academicYear: ctx.academicYear,
        );
      }

      if (!mounted) return;
      setState(() {
        _availableEstablishments = establishments;
        _availableChildren = children;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserFriendlyErrors.from(e))));
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingSelector = false;
      });
    }
  }

  Future<void> _onEstablishmentChanged(String? establishmentId) async {
    if (establishmentId == null || establishmentId.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final establishmentsService = EstablishmentsService(api);

      Map<String, dynamic> resp;
      try {
        resp = await establishmentsService.switchEstablishment(
          establishmentId: establishmentId,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (!refreshed) {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
          resp = await establishmentsService.switchEstablishment(
            establishmentId: establishmentId,
          );
        } else {
          rethrow;
        }
      }

      final ctx = context.read<ParentContextProvider>();
      final tenantId =
          (resp['tenant_id'] as num?)?.toInt() ??
          (resp['tenantId'] as num?)?.toInt();
      final subdomain = resp['subdomain']?.toString() ?? establishmentId;
      final name =
          resp['establishment_name']?.toString() ??
          resp['name']?.toString() ??
          establishmentId;

      if (tenantId != null) {
        ctx.setEstablishment(
          SelectedEstablishment(
            subdomain: subdomain,
            tenantId: tenantId,
            name: name,
            logo: resp['logo']?.toString(),
            city: resp['city']?.toString(),
          ),
        );
      }

      final selectedYear = resp['selected_year']?.toString();
      if (selectedYear != null && selectedYear.trim().isNotEmpty) {
        ctx.setAcademicYear(selectedYear);
      }

      ctx.clearChild();

      await _loadSelectorData();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserFriendlyErrors.from(e))));
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onChildChanged(int? childId) async {
    if (childId == null) return;
    final found = _availableChildren
        .where((c) => (c['id'] as num?)?.toInt() == childId)
        .toList(growable: false);
    if (found.isEmpty) return;

    final raw = found.first;
    final ctx = context.read<ParentContextProvider>();
    ctx.setChild(
      SelectedChild(
        id: childId,
        fullName: raw['full_name']?.toString() ?? raw['name']?.toString() ?? '',
        className: raw['class_name']?.toString(),
      ),
    );

    await _load();
  }

  Widget _buildContextDropdowns(BuildContext context) {
    final ctx = context.watch<ParentContextProvider>();
    final selectedEstId = ctx.establishment?.subdomain;
    final selectedChildId = ctx.child?.id;

    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedEstId,
                hint: const Text('École'),
                items: _availableEstablishments
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e['id']?.toString(),
                        child: Text(e['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _loadingSelector || _loading
                    ? null
                    : (value) async {
                        await _onEstablishmentChanged(value);
                      },
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedChildId,
                hint: const Text('Élève'),
                items: _availableChildren
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: (c['id'] as num?)?.toInt(),
                        child: Text(
                          c['full_name']?.toString() ??
                              c['name']?.toString() ??
                              '',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _loadingSelector || _loading
                    ? null
                    : (value) async {
                        await _onChildChanged(value);
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final service = ModulesService(api);
      final ctx = context.read<ParentContextProvider>();

      final hasEstablishment = ctx.establishment != null;
      final eleveId = ctx.child?.id;
      if (!hasEstablishment) {
        throw Exception('Veuillez sélectionner une école');
      }
      if (eleveId == null) {
        throw Exception('Veuillez sélectionner un enfant');
      }

      Future<Map<String, dynamic>> run() {
        switch (widget.kind) {
          case ModuleKind.notes:
            return service.fetchNotes(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
          case ModuleKind.homework:
            return service.fetchHomework(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
          case ModuleKind.bulletins:
            return service.fetchBulletins(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
          case ModuleKind.notifications:
            return service.fetchNotifications(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
          case ModuleKind.scolarites:
            return service.fetchScolarites(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
          case ModuleKind.absences:
            return service.fetchAbsences(
              eleveId: eleveId,
              annee: ctx.academicYear,
            );
        }
      }

      Map<String, dynamic> resp;
      try {
        resp = await run();
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (!refreshed) {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
          resp = await run();
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _data = resp;
      });

      if (widget.kind == ModuleKind.bulletins) {
        final raw = resp['examens_disponibles'];
        final list = (raw is List)
            ? raw
                  .whereType<Map>()
                  .map((e) {
                    return e.map((k, v) => MapEntry(k.toString(), v));
                  })
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        final selected = resp['selected_examen_id'];
        setState(() {
          _availableBulletinExams = list;
          _selectedBulletinId = (selected is num)
              ? selected.toInt()
              : int.tryParse(selected?.toString() ?? '');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
            child: const Text('Tableau de bord'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: _buildContextDropdowns(context),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget());
    }

    if (_error != null) {
      return Center(
        child: custom.ErrorWidget(message: _error!, onRetry: _load),
      );
    }

    if (widget.kind == ModuleKind.notes) {
      return _buildNotesBody(context);
    }

    if (widget.kind == ModuleKind.homework) {
      return _buildHomeworkBody(context);
    }

    if (widget.kind == ModuleKind.bulletins) {
      return _buildBulletinsBody(context);
    }

    if (widget.kind == ModuleKind.scolarites) {
      return _buildScolaritesBody(context);
    }

    if (widget.kind == ModuleKind.absences) {
      return _buildAbsencesBody(context);
    }

    final listCandidate =
        _data?['results'] ??
        _data?['data'] ??
        _data?['items'] ??
        _data?['notes'] ??
        _data?['homework'] ??
        _data?['bulletins'] ??
        _data?['notifications'] ??
        _data?['scolarites'];

    if (listCandidate is! List || listCandidate.isEmpty) {
      return Center(
        child: Text(
          'Aucune donnée.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final items = listCandidate
        .whereType<Map>()
        .map((e) {
          return e.map((k, v) => MapEntry(k.toString(), v));
        })
        .toList(growable: false);

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
      itemBuilder: (context, index) {
        final item = items[index];
        final title =
            item['title']?.toString() ??
            item['matiere']?.toString() ??
            item['subject']?.toString() ??
            item['libelle']?.toString() ??
            item['name']?.toString() ??
            'Élément ${index + 1}';
        final subtitle =
            item['date']?.toString() ??
            item['created_at']?.toString() ??
            item['periode']?.toString() ??
            item['message']?.toString() ??
            '';

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppTheme.sm),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeworkBody(BuildContext context) {
    final evaluations = _data?['evaluations'];
    if (evaluations is! Map) {
      return Center(
        child: Text(
          'Aucune donnée.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    List<Map<String, dynamic>> _normalizeList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) {
            return e.map((k, v) => MapEntry(k.toString(), v));
          })
          .toList(growable: false);
    }

    final upcomingRaw = _normalizeList(evaluations['upcoming']);
    final overdueRaw = _normalizeList(evaluations['overdue']);
    final completedRaw = _normalizeList(evaluations['completed']);

    final List<Map<String, dynamic>> upcoming = [];
    final List<Map<String, dynamic>> overdue = [];
    final List<Map<String, dynamic>> completed = [...completedRaw];

    bool _hasNote(Map<String, dynamic> item) {
      final note = item['note'];
      if (note == null) return false;
      if (note is num) return true;
      final s = note.toString().trim();
      return s.isNotEmpty;
    }

    for (final item in upcomingRaw) {
      if (_hasNote(item)) {
        completed.add(item);
      } else {
        upcoming.add(item);
      }
    }
    for (final item in overdueRaw) {
      if (_hasNote(item)) {
        completed.add(item);
      } else {
        overdue.add(item);
      }
    }

    final upcomingCount = upcoming.length;
    final overdueCount = overdue.length;
    final completedCount = completed.length;

    final hasAny =
        upcoming.isNotEmpty || overdue.isNotEmpty || completed.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Text(
          'Aucun devoir.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    Widget section(
      String title,
      List<Map<String, dynamic>> items,
      dynamic count,
    ) {
      if (items.isEmpty) return const SizedBox.shrink();
      final countLabel = (count is num)
          ? count.toInt().toString()
          : count?.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              bottom: AppTheme.md,
              top: AppTheme.lg,
            ),
            child: Text(
              countLabel == null || countLabel.isEmpty
                  ? title
                  : '$title ($countLabel)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...items.map((item) {
            final subject = item['matiere']?.toString() ?? 'Matière';
            final type = item['type']?.toString() ?? '';
            final date = _formatDate(item['date']?.toString());
            final startTime = item['start_time']?.toString();
            final endTime = item['end_time']?.toString();
            final observation = item['observation']?.toString() ?? '';
            final note = item['note'];
            final noteMax = item['note_max'];

            String timeLabel = '';
            if (startTime != null && startTime.isNotEmpty) {
              final st = DateTime.tryParse(startTime);
              if (st != null) {
                timeLabel =
                    '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}';
              }
            }
            if (endTime != null && endTime.isNotEmpty) {
              final et = DateTime.tryParse(endTime);
              if (et != null) {
                final endLabel =
                    '${et.hour.toString().padLeft(2, '0')}:${et.minute.toString().padLeft(2, '0')}';
                timeLabel = timeLabel.isEmpty
                    ? endLabel
                    : '$timeLabel - $endLabel';
              }
            }

            final noteLabel = (note == null)
                ? ''
                : _formatNoteValue(note, scale: noteMax);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (noteLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.md,
                            vertical: AppTheme.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                          ),
                          child: Text(
                            noteLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sm),
                  if (type.isNotEmpty)
                    Text(type, style: Theme.of(context).textTheme.bodyMedium),
                  if (date.isNotEmpty || timeLabel.isNotEmpty)
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (timeLabel.isNotEmpty) timeLabel,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (observation.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      observation,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.lg),
      children: [
        section('À venir', upcoming, upcomingCount),
        section('En retard', overdue, overdueCount),
        section('Terminés', completed, completedCount),
      ],
    );
  }

  Widget _buildNotesBody(BuildContext context) {
    final notesRaw = _data?['notes'];
    final examsRaw = _data?['exams'];

    final notes = (notesRaw is List)
        ? notesRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final exams = (examsRaw is List)
        ? examsRaw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final stats = _data?['stats'];
    final noteScale = _data?['note_scale'];
    final notesAvg = (stats is Map) ? stats['notes_average'] : null;
    final examsAvg = (stats is Map) ? stats['exam_notes_average'] : null;

    final hasAny = notes.isNotEmpty || exams.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Text(
          'Aucune note.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.lg),
      children: [
        if (notesAvg != null || examsAvg != null)
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            margin: const EdgeInsets.only(bottom: AppTheme.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moyennes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.sm),
                if (notesAvg != null)
                  Text(
                    'Notes: ${_formatNoteValue(notesAvg, scale: noteScale)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (examsAvg != null)
                  Text(
                    'Examens: ${_formatNoteValue(examsAvg, scale: noteScale)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),

        if (notes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.md),
            child: Text(
              'Notes de classe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...notes.map((item) {
            final subject = item['matiere']?.toString() ?? 'Matière';
            final date = _formatDate(item['date']?.toString());
            final value = item['value'];
            final evaluation = item['evaluation'];
            final evalTitle = (evaluation is Map)
                ? (evaluation['title']?.toString() ?? '')
                : '';
            final evalType = (evaluation is Map)
                ? (evaluation['type']?.toString() ?? '')
                : '';
            final coef = (evaluation is Map) ? evaluation['coefficient'] : null;

            final valueLabel = _formatNoteValue(value, scale: noteScale);
            final coefLabel = (coef == null)
                ? ''
                : (coef is num && coef % 1 == 0)
                ? coef.toInt().toString()
                : coef.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.md,
                      vertical: AppTheme.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Text(
                      valueLabel.isNotEmpty ? valueLabel : '-',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.sm),
                        if (evalTitle.isNotEmpty)
                          Text(
                            evalTitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (evalType.isNotEmpty || coefLabel.isNotEmpty)
                          Text(
                            [
                              if (evalType.isNotEmpty) evalType,
                              if (coefLabel.isNotEmpty) 'Coef $coefLabel',
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppTheme.lg),
        ],

        if (exams.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.md),
            child: Text(
              'Notes d\'examen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...exams.map((item) {
            final subject = item['matiere']?.toString() ?? 'Matière';
            final date = _formatDate(item['date']?.toString());
            final value = item['value'];
            final valueLabel = _formatNoteValue(value, scale: noteScale);

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.md,
                      vertical: AppTheme.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Text(
                      valueLabel.isNotEmpty ? valueLabel : '-',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.sm),
                          Text(
                            date,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
