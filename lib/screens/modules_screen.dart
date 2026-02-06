import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/children_service.dart';
import '../services/establishments_service.dart';
import '../services/modules_service.dart';
import '../utils/formatters.dart';
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
  final bool includeScaffold;
  final bool includeTopContextHeader;

  const ModulesScreen({
    super.key,
    required this.kind,
    this.includeScaffold = true,
    this.includeTopContextHeader = true,
  });

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _data;

  bool _refreshing = false;

  List<Map<String, dynamic>> _availableEstablishments = const [];
  List<Map<String, dynamic>> _availableChildren = const [];
  bool _loadingSelector = false;

  bool _initialized = false;

  int? _selectedBulletinId;
  List<Map<String, dynamic>> _availableBulletinExams = const [];

  Timer? _estDebounce;
  Timer? _childDebounce;

  bool _wasPaused = false;

  Widget _futuristicCard(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppTheme.lg),
    EdgeInsetsGeometry? margin,
  }) {
    final glowA = const Color(0xFF00E676);
    final glowB = const Color(0xFF00BFA5);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: glowA.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          AppTheme.shadowSmall,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceColor.withOpacity(0.96),
                  AppTheme.surfaceColor.withOpacity(0.86),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: glowB.withOpacity(0.20), width: 1.1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _estDebounce?.cancel();
    _childDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _loadSelectorData();
      _load();
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = DateTime(dt.year, dt.month, dt.day);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _scheduleEstablishmentChange(String? establishmentId) {
    _estDebounce?.cancel();
    _estDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _onEstablishmentChanged(establishmentId);
    });
  }

  void _scheduleChildChange(int? childId) {
    _childDebounce?.cancel();
    _childDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _onChildChanged(childId);
    });
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
      padding: const EdgeInsets.only(
        left: AppTheme.lg,
        right: AppTheme.lg,
        top: AppTheme.lg,
        bottom: 160, // Espace pour la barre de navigation
      ),
      children: [
        _futuristicCard(
          Column(
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

        _futuristicCard(
          DropdownButtonHideUnderline(
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
                      await _reloadWithExtraParams({'status': value});
                    },
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.lg,
            vertical: AppTheme.md,
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        if (absences.isEmpty)
          _futuristicCard(
            Row(
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
            final matiere = AppFormatters.cleanSubjectName(
              a['matiere']?.toString() ?? '',
            );
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
      _refreshing = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final resp = await api
          .get<Map<String, dynamic>>(
            '/parent/absences/',
            queryParameters: {
              'eleve_id': eleveId,
              if (ctx.academicYear != null) 'annee': ctx.academicYear,
              ...extra,
            },
          )
          .timeout(const Duration(seconds: 15));

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
        _refreshing = false;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Aucune donnée de scolarité.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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

    IconData _getTrancheIcon(String? statut) {
      final v = (statut ?? '').toLowerCase();
      if (v.contains('paye') || v.contains('paid') || v.contains('valide')) {
        return Icons.check_circle;
      }
      if (v.contains('attente') || v.contains('pending')) {
        return Icons.pending;
      }
      if (v.contains('retard') ||
          v.contains('overdue') ||
          v.contains('impaye')) {
        return Icons.warning;
      }
      return Icons.payment;
    }

    IconData _getPaymentIcon(String? mode) {
      final v = (mode ?? '').toLowerCase();
      if (v.contains('especes') || v.contains('cash')) {
        return Icons.money;
      }
      if (v.contains('carte') || v.contains('card')) {
        return Icons.credit_card;
      }
      if (v.contains('mobile') || v.contains('orange') || v.contains('mtn')) {
        return Icons.phone_android;
      }
      if (v.contains('banque') ||
          v.contains('bank') ||
          v.contains('virement')) {
        return Icons.account_balance;
      }
      if (v.contains('cheque')) {
        return Icons.description;
      }
      return Icons.receipt_long;
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
      padding: const EdgeInsets.only(
        left: AppTheme.lg,
        right: AppTheme.lg,
        bottom: AppTheme.lg,
        top: AppTheme.sm,
      ),
      children: [
        _futuristicCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.60),
                          AppTheme.primaryColor.withOpacity(0.20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: [
                        // Glow effect principal
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.60),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                        // Glow secondaire
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.40),
                          blurRadius: 40,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                        // Ombre subtile pour profondeur
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Récapitulatif',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor,
                              ),
                        ),
                        if (periodeLabel.trim().isNotEmpty) ...[
                          const SizedBox(height: AppTheme.xs),
                          Text(
                            periodeLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (fullyPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.lg,
                        vertical: AppTheme.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.successColor,
                            AppTheme.successColor.withOpacity(0.70),
                            AppTheme.successColor.withOpacity(0.30),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        boxShadow: [
                          // Glow effect principal
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.50),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 0),
                          ),
                          // Glow secondaire
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.30),
                            blurRadius: 25,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 0),
                          ),
                          // Ombre subtile pour profondeur
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: AppTheme.xs),
                          Text(
                            'Soldé',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.lg),
              Row(
                children: [
                  Expanded(
                    child: _enhancedKpiTile(
                      context,
                      label: 'Total',
                      value: money(total),
                      icon: Icons.account_balance,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _enhancedKpiTile(
                      context,
                      label: 'Payé',
                      value: money(paid),
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: _enhancedKpiTile(
                      context,
                      label: 'Reste',
                      value: money(remaining),
                      icon: Icons.account_balance_wallet,
                      color: remainingNum != null && remainingNum > 0
                          ? AppTheme.warningColor
                          : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.lg),
              Container(
                padding: const EdgeInsets.all(AppTheme.md),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: progressColor.withOpacity(0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progression du paiement',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(clamped * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sm),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: LinearProgressIndicator(
                          minHeight: 12,
                          value: clamped,
                          backgroundColor: AppTheme.borderColor.withOpacity(
                            0.20,
                          ),
                          color: progressColor,
                        ),
                      ),
                    ),
                    if (paidNum != null && totalNum != null) ...[
                      const SizedBox(height: AppTheme.sm),
                      Text(
                        '${money(paidNum)} payé sur ${money(totalNum)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        if (tranches.isNotEmpty) ...[
          _futuristicCard(
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.warningColor,
                            AppTheme.warningColor.withOpacity(0.80),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.warningColor.withOpacity(0.30),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_month,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        'Tranches',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                      child: Text(
                        '${tranches.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          ...tranches.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
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

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 50)),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: color.withOpacity(0.30), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  AppTheme.shadowSmall,
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  onTap: () {
                    // TODO: Add navigation to tranche details
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.sm),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withOpacity(0.15),
                                    color.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                border: Border.all(
                                  color: color.withOpacity(0.30),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getTrancheIcon(statut),
                                size: 20,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                  ),
                                  if (echeance.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.xs),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 14,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(width: AppTheme.xs),
                                        Text(
                                          'Échéance: $echeance',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                                  gradient: LinearGradient(
                                    colors: [color, color.withOpacity(0.80)],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.30),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  statut,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.sm),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Montant: $montant',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Payé: $montantPaye',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (cl != null) ...[
                          const SizedBox(height: AppTheme.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progression',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${(cl * 100).toStringAsFixed(0)}%',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.sm),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    value: cl,
                                    backgroundColor: AppTheme.borderColor
                                        .withOpacity(0.20),
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppTheme.lg),
        ],

        if (payments.isNotEmpty) ...[
          _futuristicCard(
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.infoColor,
                            AppTheme.infoColor.withOpacity(0.80),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.infoColor.withOpacity(0.30),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.history,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        'Paiements récents',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                      child: Text(
                        '${payments.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          ...payments.take(20).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final p = entry.value;
            final amount = money(p['montant_paye']);
            final date = _formatDate(p['date_paiement']?.toString());
            final mode = p['mode_paiement']?.toString() ?? '';
            final statut = p['statut']?.toString() ?? '';
            final trancheId = p['tranche_id']?.toString() ?? '';
            final color = statusColor(statut);

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 30).toInt()),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: color.withOpacity(0.20), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  AppTheme.shadowSmall,
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  onTap: () {
                    // TODO: Add navigation to payment details
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.sm),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.12),
                                color.withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(
                              color: color.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getPaymentIcon(mode),
                            size: 20,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                amount,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                              ),
                              const SizedBox(height: AppTheme.sm),
                              Row(
                                children: [
                                  if (date.isNotEmpty) ...[
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    const SizedBox(width: AppTheme.xs),
                                    Text(
                                      date,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                    ),
                                  ],
                                  if (mode.isNotEmpty && date.isNotEmpty) ...[
                                    const SizedBox(width: AppTheme.sm),
                                    Text(
                                      '•',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textTertiaryColor,
                                          ),
                                    ),
                                    const SizedBox(width: AppTheme.sm),
                                  ],
                                  if (mode.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        mode,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.w500,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (trancheId.isNotEmpty) ...[
                                    if (mode.isNotEmpty) ...[
                                      const SizedBox(width: AppTheme.sm),
                                      Text(
                                        '•',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textTertiaryColor,
                                            ),
                                      ),
                                      const SizedBox(width: AppTheme.sm),
                                    ],
                                    Text(
                                      'T$trancheId',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ],
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
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.80)],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              statut,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 100), // Espace pour la barre de navigation
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
        setState(() {
          _loading = false;
          _error = 'Veuillez sélectionner une école pour continuer';
        });
        return;
      }
      if (eleveId == null) {
        setState(() {
          _loading = false;
          _error = 'Veuillez sélectionner un enfant pour continuer';
        });
        return;
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
        resp = await run().timeout(const Duration(seconds: 15));
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
          resp = await run().timeout(const Duration(seconds: 15));
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
      padding: const EdgeInsets.only(
        left: AppTheme.lg,
        right: AppTheme.lg,
        bottom: AppTheme.lg,
        top: AppTheme.sm,
      ),
      children: [
        if (examItems.isNotEmpty)
          _futuristicCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.80),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.30),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        'Examen / Bulletin',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.20),
                      width: 1.5,
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
                            final date = _formatDate(
                              e['date_examen']?.toString(),
                            );
                            final label = [
                              if (examen.isNotEmpty) examen,
                              if (per.isNotEmpty) per,
                              if (date.isNotEmpty) date,
                            ].join(' • ');
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.md,
                                  vertical: AppTheme.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSmall,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.description,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.sm),
                                    Expanded(
                                      child: Text(
                                        label.isNotEmpty ? label : 'Bulletin',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
              ],
            ),
            padding: const EdgeInsets.all(AppTheme.lg),
          ),
        if (examItems.isEmpty)
          _futuristicCard(
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 48,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Aucun examen disponible',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  'Aucun examen disponible pour cet élève sur la période sélectionnée.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppTheme.lg),

        if (current == null)
          _futuristicCard(
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: AppTheme.infoColor,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Aucun bulletin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          _futuristicCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.md),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successColor,
                            AppTheme.successColor.withOpacity(0.80),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam?['nom']?.toString() ?? 'Bulletin',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                          ),
                          const SizedBox(height: AppTheme.xs),
                          Text(
                            [
                                  periode?['nom']?.toString(),
                                  if (exam != null)
                                    _formatDate(exam['date']?.toString()),
                                ]
                                .whereType<String>()
                                .where((s) => s.trim().isNotEmpty)
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                    if (mention != null && mention.toString().trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentColor,
                              AppTheme.accentColor.withOpacity(0.80),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withOpacity(0.30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: AppTheme.xs),
                            Text(
                              mention.toString(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.lg),
                Row(
                  children: [
                    Expanded(
                      child: _enhancedKpiTile(
                        context,
                        label: 'Moyenne',
                        value: moyenne == null
                            ? '-'
                            : _formatNoteValue(moyenne, scale: noteMax),
                        icon: Icons.analytics,
                        color: _getNoteColor(moyenne, noteMax),
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: _enhancedKpiTile(
                        context,
                        label: 'Classement',
                        value: classement?.toString() ?? '-',
                        icon: Icons.leaderboard,
                        color: AppTheme.infoColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: _enhancedKpiTile(
                        context,
                        label: 'Réussite',
                        value: successRate == null
                            ? '-'
                            : '${successRate.toString()}%',
                        icon: Icons.trending_up,
                        color: _getSuccessColor(successRate),
                      ),
                    ),
                  ],
                ),

                if (topMatiere != null || bottomMatiere != null) ...[
                  const SizedBox(height: AppTheme.lg),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surfaceColor,
                          AppTheme.backgroundColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppTheme.borderColor.withOpacity(0.50),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (topMatiere != null)
                          Expanded(
                            child: _enhancedHighlightTile(
                              context,
                              title: 'Meilleure matière',
                              subject: AppFormatters.cleanSubjectName(
                                topMatiere['nom']?.toString() ?? '-',
                              ),
                              value: _formatNoteValue(
                                topMatiere['note'],
                                scale: noteMax,
                              ),
                              color: AppTheme.successColor,
                              icon: Icons.emoji_events,
                            ),
                          ),
                        if (topMatiere != null && bottomMatiere != null)
                          const SizedBox(width: AppTheme.md),
                        if (bottomMatiere != null)
                          Expanded(
                            child: _enhancedHighlightTile(
                              context,
                              title: 'À améliorer',
                              subject: AppFormatters.cleanSubjectName(
                                bottomMatiere['nom']?.toString() ?? '-',
                              ),
                              value: _formatNoteValue(
                                bottomMatiere['note'],
                                scale: noteMax,
                              ),
                              color: AppTheme.warningColor,
                              icon: Icons.trending_up,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.lg),

          if (matieres.isNotEmpty)
            _futuristicCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.sm),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.infoColor,
                              AppTheme.infoColor.withOpacity(0.80),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.infoColor.withOpacity(0.30),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          'Détails par matière',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.md,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        child: Text(
                          '${matieres.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: AppTheme.md,
              ),
            ),
          const SizedBox(height: AppTheme.md),
          ...matieres.asMap().entries.map((entry) {
            final index = entry.key;
            final m = entry.value;
            final matiere = AppFormatters.cleanSubjectName(
              m['matiere']?.toString() ?? 'Matière',
            );
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

            final noteColor = _getNoteColor(note, max);

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 40)),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: noteColor.withOpacity(0.30),
                  width: 2,
                ),
                boxShadow: [
                  // Glow effect principal basé sur la note
                  BoxShadow(
                    color: noteColor.withOpacity(0.40),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 0),
                  ),
                  // Glow secondaire plus subtil
                  BoxShadow(
                    color: noteColor.withOpacity(0.25),
                    blurRadius: 35,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 0),
                  ),
                  // Ombre de profondeur
                  AppTheme.shadowSmall,
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  onTap: () {
                    // TODO: Add navigation to subject details
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.sm),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    noteColor.withOpacity(0.12),
                                    noteColor.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                border: Border.all(
                                  color: noteColor.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getSubjectIcon(matiere),
                                size: 20,
                                color: noteColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matiere,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                  ),
                                  if (coefLabel.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.xs),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.format_list_numbered,
                                          size: 14,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(width: AppTheme.xs),
                                        Text(
                                          'Coef $coefLabel',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                        ),
                                      ],
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
                                gradient: RadialGradient(
                                  colors: [
                                    noteColor,
                                    noteColor.withOpacity(0.80),
                                    noteColor.withOpacity(0.40),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                                boxShadow: [
                                  // Glow effect principal
                                  BoxShadow(
                                    color: noteColor.withOpacity(0.60),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 0),
                                  ),
                                  // Glow secondaire
                                  BoxShadow(
                                    color: noteColor.withOpacity(0.40),
                                    blurRadius: 25,
                                    spreadRadius: 0.5,
                                    offset: const Offset(0, 0),
                                  ),
                                  // Ombre subtile pour profondeur
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                valueLabel.isNotEmpty ? valueLabel : '-',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (clamped != null) ...[
                          const SizedBox(height: AppTheme.md),
                          Container(
                            padding: const EdgeInsets.all(AppTheme.sm),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progression',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Text(
                                      '${(clamped * 100).toStringAsFixed(0)}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: noteColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sm),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 800),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLarge,
                                    ),
                                    child: LinearProgressIndicator(
                                      minHeight: 8,
                                      value: clamped,
                                      backgroundColor: AppTheme.borderColor
                                          .withOpacity(0.20),
                                      color: noteColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 100), // Espace pour la barre de navigation
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

  Widget _enhancedKpiTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.20), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.xs),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhancedHighlightTile(
    BuildContext context, {
    required String title,
    required String subject,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.20), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.xs),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            subject,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoteColor(dynamic note, dynamic noteMax) {
    if (note == null) return AppTheme.textSecondaryColor;
    final noteValue = note is num
        ? note.toDouble()
        : double.tryParse(note.toString());
    final maxValue = noteMax is num
        ? noteMax.toDouble()
        : double.tryParse(noteMax?.toString() ?? '20') ?? 20.0;

    if (noteValue == null) return AppTheme.textSecondaryColor;

    final percentage = noteValue / maxValue;
    if (percentage >= 0.8) return AppTheme.successColor;
    if (percentage >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getSuccessColor(dynamic successRate) {
    if (successRate == null) return AppTheme.textSecondaryColor;
    final rate = successRate is num
        ? successRate.toDouble()
        : double.tryParse(successRate.toString());
    if (rate == null) return AppTheme.textSecondaryColor;

    if (rate >= 80) return AppTheme.successColor;
    if (rate >= 60) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  IconData _getSubjectIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math') || s.contains('maths')) return Icons.calculate;
    if (s.contains('français') || s.contains('francais'))
      return Icons.menu_book;
    if (s.contains('anglais') || s.contains('english')) return Icons.language;
    if (s.contains('physique') || s.contains('chimie')) return Icons.science;
    if (s.contains('histoire') || s.contains('géographie')) return Icons.public;
    if (s.contains('sport') || s.contains('eps')) return Icons.fitness_center;
    if (s.contains('musique')) return Icons.music_note;
    if (s.contains('art') || s.contains('dessin')) return Icons.palette;
    if (s.contains('informatique') || s.contains('tech')) return Icons.computer;
    return Icons.school;
  }

  Color _getGradeColor(dynamic value, {dynamic scale}) {
    if (value == null) return AppTheme.textTertiaryColor;
    final numValue = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;
    final maxScale = scale is num
        ? scale.toDouble()
        : (scale != null ? double.tryParse(scale.toString()) : null) ?? 20;
    final percentage = maxScale > 0 ? (numValue / maxScale) * 100 : 0;

    if (percentage < 50) return const Color(0xFFE53935); // Rouge
    if (percentage < 70) return const Color(0xFFFB8C00); // Orange
    if (percentage < 85) return const Color(0xFFFDD835); // Jaune
    return const Color(0xFF43A047); // Vert
  }

  Widget _buildEnhancedGradeBadge(
    BuildContext context,
    dynamic value, {
    dynamic scale,
    bool isExam = false,
  }) {
    final valueLabel = _formatNoteValue(value, scale: scale);
    final gradeColor = _getGradeColor(value, scale: scale);
    final bgColor = gradeColor.withOpacity(0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueLabel.isNotEmpty ? valueLabel : '-',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: gradeColor,
              fontSize: 18,
            ),
          ),
          if (isExam)
            Text(
              'EXAMEN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: gradeColor.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteDetailChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    Color? color,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final chipColor = color ?? AppTheme.textSecondaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md, top: AppTheme.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGradeComment(dynamic value, {dynamic scale}) {
    if (value == null) return '';
    final numValue = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;
    final maxScale = scale is num
        ? scale.toDouble()
        : (scale != null ? double.tryParse(scale.toString()) : null) ?? 20;
    final percentage = maxScale > 0 ? (numValue / maxScale) * 100 : 0;

    if (percentage < 50) return 'À améliorer';
    if (percentage < 70) return 'Moyen';
    if (percentage < 85) return 'Bien';
    if (percentage < 95) return 'Très bien';
    return 'Excellent';
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

  String _formatFraction(dynamic v, dynamic s) {
    if (v == null || s == null) return '-';
    return '$v/$s';
  }

  InputDecoration _glassDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white.withOpacity(0.82),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.55)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
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
            decoration: _glassDropdownDecoration('École'),
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
                    : (value) {
                        _scheduleEstablishmentChange(value);
                      },
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: InputDecorator(
            decoration: _glassDropdownDecoration('Élève'),
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
                    : (value) {
                        _scheduleChildChange(value);
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
      _refreshing = _data != null;
      _loading = _data == null;
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
        setState(() {
          _loading = false;
          _error = 'Veuillez sélectionner une école pour continuer';
        });
        return;
      }
      if (eleveId == null) {
        setState(() {
          _loading = false;
          _error = 'Veuillez sélectionner un enfant pour continuer';
        });
        return;
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
    final body = Column(
      children: [
        if (widget.includeTopContextHeader)
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
    );

    if (!widget.includeScaffold) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(_title)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return Center(
        child: custom.ErrorWidget(message: _error!, onRetry: _load),
      );
    }

    Widget body;
    if (widget.kind == ModuleKind.notes) {
      body = _buildNotesBody(context);
    } else if (widget.kind == ModuleKind.homework) {
      body = _buildHomeworkBody(context);
    } else if (widget.kind == ModuleKind.bulletins) {
      body = _buildBulletinsBody(context);
    } else if (widget.kind == ModuleKind.notifications) {
      body = _buildNotificationsBody(context);
    } else if (widget.kind == ModuleKind.scolarites) {
      body = _buildScolaritesBody(context);
    } else if (widget.kind == ModuleKind.absences) {
      body = _buildAbsencesBody(context);
    } else {
      body = const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          body,
          if (_refreshing)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: const LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeworkBody(BuildContext context) {
    final evaluations = _data?['evaluations'];
    if (evaluations is! Map) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Aucune donnée.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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
      Color sectionColor,
      IconData sectionIcon,
    ) {
      if (items.isEmpty) return const SizedBox.shrink();
      final countLabel = (count is num)
          ? count.toInt().toString()
          : count?.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  sectionColor.withOpacity(0.10),
                  sectionColor.withOpacity(0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: sectionColor.withOpacity(0.20),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(sectionIcon, size: 20, color: sectionColor),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    countLabel == null || countLabel.isEmpty
                        ? title
                        : '$title ($countLabel)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: sectionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.md,
                    vertical: AppTheme.xs,
                  ),
                  decoration: BoxDecoration(
                    color: sectionColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Text(
                    countLabel ?? '0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final subject = AppFormatters.cleanSubjectName(
              item['matiere']?.toString() ?? 'Matière',
            );
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

            final hasGrade = noteLabel.isNotEmpty;
            final isOverdue = title == 'Passé';
            final isUpcoming = title == 'À venir';
            final isCompleted = title == 'Terminés';

            Color cardColor = Colors.white;
            Color borderColor = AppTheme.borderColor;
            Color statusColor = Colors.grey;
            IconData statusIcon = Icons.assignment;

            if (isOverdue) {
              statusColor = AppTheme.errorColor;
              statusIcon = Icons.assignment_late;
              borderColor = AppTheme.errorColor.withOpacity(0.30);
            } else if (isUpcoming) {
              statusColor = AppTheme.warningColor;
              statusIcon = Icons.pending;
              borderColor = AppTheme.warningColor.withOpacity(0.30);
            } else if (isCompleted) {
              statusColor = AppTheme.successColor;
              statusIcon = Icons.assignment_turned_in;
              borderColor = AppTheme.successColor.withOpacity(0.30);
            }

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 50)),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  AppTheme.shadowSmall,
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  onTap: () {
                    // TODO: Add navigation to homework details
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.sm),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.30),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                statusIcon,
                                size: 20,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                  ),
                                  const SizedBox(height: AppTheme.xs),
                                  if (type.isNotEmpty)
                                    Text(
                                      type,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (hasGrade)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.md,
                                  vertical: AppTheme.sm,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.successColor,
                                      AppTheme.successColor.withOpacity(0.80),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.successColor.withOpacity(
                                        0.30,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  noteLabel,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        if (date.isNotEmpty || timeLabel.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.sm,
                              vertical: AppTheme.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                const SizedBox(width: AppTheme.xs),
                                Text(
                                  [
                                    if (date.isNotEmpty) date,
                                    if (timeLabel.isNotEmpty) timeLabel,
                                  ].join(' • '),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (observation.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.sm),
                            decoration: BoxDecoration(
                              color: AppTheme.infoColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                              border: Border.all(
                                color: AppTheme.infoColor.withOpacity(0.20),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: AppTheme.infoColor,
                                ),
                                const SizedBox(width: AppTheme.xs),
                                Expanded(
                                  child: Text(
                                    observation,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.infoColor,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
        left: AppTheme.lg,
        right: AppTheme.lg,
        bottom: AppTheme.lg,
        top: AppTheme.sm,
      ),
      children: [
        section(
          'À venir',
          upcoming,
          upcomingCount,
          AppTheme.warningColor,
          Icons.upcoming,
        ),
        section(
          'Passé',
          overdue,
          overdueCount,
          AppTheme.errorColor,
          Icons.assignment_late,
        ),
        section(
          'Terminés',
          completed,
          completedCount,
          AppTheme.successColor,
          Icons.check_circle,
        ),
        const SizedBox(height: 100), // Espace pour la barre de navigation
      ],
    );
  }

  Widget _buildNotificationsBody(BuildContext context) {
    final raw = _data?['notifications'];
    final notifications = (raw is List)
        ? raw
              .whereType<Map>()
              .map((e) {
                return e.map((k, v) => MapEntry(k.toString(), v));
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    if (notifications.isEmpty) {
      return Center(
        child: Text(
          'Aucune notification.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTheme.lg,
        AppTheme.lg,
        AppTheme.lg,
        AppTheme.lg + 84 + bottomInset,
      ),
      children: notifications
          .map((n) {
            final title = n['title']?.toString() ?? '';
            final message = n['message']?.toString() ?? '';
            final type = n['type']?.toString() ?? '';
            final isRead = n['is_read'] == true;
            final date = _formatDate(n['created_at']?.toString());

            final student = (n['student'] is Map)
                ? Map<String, dynamic>.from(n['student'] as Map)
                : const <String, dynamic>{};
            final studentLabel = [
              if ((student['prenom'] ?? '').toString().trim().isNotEmpty)
                student['prenom'].toString().trim(),
              if ((student['nom'] ?? '').toString().trim().isNotEmpty)
                student['nom'].toString().trim(),
            ].join(' ');

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.md),
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: isRead
                      ? AppTheme.borderColor
                      : AppTheme.primaryColor.withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      color:
                          (isRead
                                  ? AppTheme.textTertiaryColor
                                  : AppTheme.primaryColor)
                              .withOpacity(0.12),
                    ),
                    child: Icon(
                      isRead ? Icons.notifications_none : Icons.notifications,
                      color: isRead
                          ? AppTheme.textTertiaryColor
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                          ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.sm),
                          Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          [
                            if (type.isNotEmpty) type,
                            if (studentLabel.isNotEmpty) studentLabel,
                            if (date.isNotEmpty) date,
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildNotesBody(BuildContext context) {
    final notesRaw = _data?['notes'];
    // L'API renvoie "exam_notes" (pas "exams"). On garde un fallback.
    final examsRaw = _data?['exam_notes'] ?? _data?['exams'];

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
    // Certaines réponses utilisent "note_max" au lieu de "note_scale".
    final noteScale = _data?['note_scale'] ?? _data?['note_max'];
    final notesAvg = (stats is Map) ? stats['notes_average'] : null;
    final examsAvg = (stats is Map) ? stats['exam_notes_average'] : null;

    final hasAny = notes.isNotEmpty || exams.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: AppTheme.textTertiaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune note disponible',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les notes de l\'élève apparaîtront ici',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: true,
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(
          left: AppTheme.lg,
          right: AppTheme.lg,
          top: AppTheme.lg,
          // Espace pour la barre de navigation du bas
          bottom: AppTheme.lg + 140 + bottomInset,
        ),
        children: [
          // Carte des moyennes améliorée
          if (notesAvg != null || examsAvg != null)
            _futuristicCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Moyennes générales',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Row(
                    children: [
                      if (notesAvg != null)
                        Expanded(
                          child: _buildAverageChip(
                            context,
                            label: 'Les notes',
                            value: _formatNoteValue(notesAvg, scale: noteScale),
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      if (notesAvg != null && examsAvg != null)
                        const SizedBox(width: AppTheme.md),
                      if (examsAvg != null)
                        Expanded(
                          child: _buildAverageChip(
                            context,
                            label: 'Examens',
                            value: _formatNoteValue(examsAvg, scale: noteScale),
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppTheme.lg),
            ),
          if (notesAvg != null || examsAvg != null)
            const SizedBox(height: AppTheme.lg),

          // Notes de classe
          if (notes.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              'Notes de classe',
              subtitle: '${notes.length} note${notes.length > 1 ? 's' : ''}',
              icon: Icons.edit_note,
            ),
            ...notes.map(
              (item) => _buildEnhancedNoteCard(
                context,
                item,
                noteScale,
                isExam: false,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],

          // Notes d'examen
          if (exams.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              'Notes d\'examen',
              subtitle: '${exams.length} examen${exams.length > 1 ? 's' : ''}',
              icon: Icons.assignment,
            ),
            ...exams.map(
              (item) => _buildEnhancedNoteCard(
                context,
                item,
                noteScale,
                isExam: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAverageChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedNoteCard(
    BuildContext context,
    Map<String, dynamic> item,
    dynamic noteScale, {
    required bool isExam,
  }) {
    final subject = AppFormatters.cleanSubjectName(
      item['matiere']?.toString() ?? 'Matière',
    );
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
    final commentaire = (evaluation is Map)
        ? (evaluation['commentaire']?.toString() ?? '')
        : '';

    final gradeColor = _getGradeColor(value, scale: noteScale);
    final gradeComment = _getGradeComment(value, scale: noteScale);
    final coefLabel = (coef == null)
        ? ''
        : (coef is num && coef % 1 == 0)
        ? coef.toInt().toString()
        : coef.toString();

    return _futuristicCard(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge de note avec code couleur
          _buildEnhancedGradeBadge(
            context,
            value,
            scale: noteScale,
            isExam: isExam,
          ),
          const SizedBox(width: AppTheme.lg),
          // Informations de la note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matière
                Text(
                  subject,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // Commentaire de performance
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gradeComment,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: gradeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Titre de l'évaluation
                if (evalTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      evalTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Commentaire du professeur
                if (commentaire.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            commentaire,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Chips d'informations (type, coefficient, date)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (evalType.isNotEmpty)
                      _buildNoteDetailChip(
                        context,
                        icon: Icons.category_outlined,
                        label: 'Type',
                        value: evalType,
                        color: AppTheme.primaryColor,
                      ),
                    if (coefLabel.isNotEmpty)
                      _buildNoteDetailChip(
                        context,
                        icon: Icons.scale_outlined,
                        label: 'Coef',
                        value: coefLabel,
                        color: Colors.blue,
                      ),
                    if (date.isNotEmpty)
                      _buildNoteDetailChip(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: date,
                        color: AppTheme.textSecondaryColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.lg),
      margin: const EdgeInsets.only(bottom: AppTheme.md),
    );
  }
}
