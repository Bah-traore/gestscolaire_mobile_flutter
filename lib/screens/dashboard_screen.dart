import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/children_service.dart';
import '../services/establishments_service.dart';
import '../utils/user_friendly_errors.dart';
import '../widgets/custom_button.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:ui';

/// Écran du tableau de bord
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _loadingEstablishments = false;
  String? _establishmentsError;
  List<Map<String, dynamic>> _establishments = const [];

  Timer? _establishmentsDebounce;
  Future<void>? _establishmentsInFlight;

  bool _loadingChildren = false;
  String? _childrenError;
  List<Map<String, dynamic>> _children = const [];

  Timer? _childrenDebounce;
  Future<void>? _childrenInFlight;

  Timer? _yearDebounce;

  List<String> _availableYears = const [];
  Map<String, String> _yearLabelToValue = const {};

  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEstablishments();
      final ctx = context.read<ParentContextProvider>();
      if (ctx.hasEstablishment) {
        _loadChildren();
      }
    });
  }

  BoxDecoration _glassCardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.86),
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      border: Border.all(color: Colors.white.withOpacity(0.55)),
      boxShadow: const [AppTheme.shadowSmall],
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.20),
                AppTheme.primaryColor.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _establishmentsDebounce?.cancel();
    _childrenDebounce?.cancel();
    _yearDebounce?.cancel();
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
      _loadEstablishments();
      final ctx = context.read<ParentContextProvider>();
      if (ctx.hasEstablishment) {
        _loadChildren();
      }
    }
  }

  Widget _buildAcademicYearSection(BuildContext context) {
    return Consumer<ParentContextProvider>(
      builder: (context, parentCtx, _) {
        if (!parentCtx.hasEstablishment) {
          return const SizedBox.shrink();
        }

        final years = _availableYears;
        if (years.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedValue = parentCtx.academicYear;
        String? selectedLabel;
        if (selectedValue != null && selectedValue.isNotEmpty) {
          for (final entry in _yearLabelToValue.entries) {
            if (entry.value == selectedValue) {
              selectedLabel = entry.key;
              break;
            }
          }
        }

        final value = (selectedLabel != null && years.contains(selectedLabel))
            ? selectedLabel
            : (years.isNotEmpty ? years.first : null);

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: _glassCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Année scolaire',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.sm),
              DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                items: years
                    .map(
                      (y) => DropdownMenuItem<String>(
                        value: y,
                        child: Text(y, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _loadingChildren
                    ? null
                    : (v) async {
                        final nextValue = v == null
                            ? null
                            : (_yearLabelToValue[v] ?? v);
                        parentCtx.setAcademicYear(nextValue);
                        _yearDebounce?.cancel();
                        _yearDebounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            if (!mounted) return;
                            _scheduleLoadChildren();
                          },
                        );
                      },
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadEstablishments() async {
    if (_establishmentsInFlight != null) {
      return _establishmentsInFlight!;
    }

    if (_loadingEstablishments && _establishments.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingEstablishments = true;
      _establishmentsError = null;
    });

    _establishmentsInFlight = () async {
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
        if (!mounted) return;
        setState(() {
          _establishments = items;
        });

        // Ne pas auto-sélectionner une école : le parent choisit toujours manuellement.
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401) {
          setState(() {
            _establishmentsError =
                'Votre session a expiré. Veuillez vous reconnecter.';
          });
          return;
        }

        setState(() {
          _establishmentsError = UserFriendlyErrors.fromDio(e);
        });
      } catch (e) {
        setState(() {
          _establishmentsError = UserFriendlyErrors.from(e);
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _loadingEstablishments = false;
        });
      }
    }();

    try {
      await _establishmentsInFlight;
    } finally {
      _establishmentsInFlight = null;
    }
  }

  void _scheduleLoadEstablishments() {
    _establishmentsDebounce?.cancel();
    _establishmentsDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadEstablishments();
    });
  }

  Future<void> _loadChildren() async {
    if (_childrenInFlight != null) {
      return _childrenInFlight!;
    }

    if (_loadingChildren && _children.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingChildren = true;
      _childrenError = null;
    });

    _childrenInFlight = () async {
      try {
        final ctx = context.read<ParentContextProvider>();
        final est = ctx.establishment;
        if (est == null) {
          return;
        }

        final api = context.read<ApiService>();
        final service = ChildrenService(api);
        final items = await service.fetchChildren(
          establishmentId: est.subdomain,
          academicYear: ctx.academicYear,
        );
        if (!mounted) return;
        setState(() {
          _children = items;
        });
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401) {
          setState(() {
            _childrenError =
                'Votre session a expiré. Veuillez vous reconnecter.';
          });
          return;
        }

        setState(() {
          _childrenError = UserFriendlyErrors.fromDio(e);
        });
      } catch (e) {
        setState(() {
          _childrenError = UserFriendlyErrors.from(e);
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _loadingChildren = false;
        });
      }
    }();

    try {
      await _childrenInFlight;
    } finally {
      _childrenInFlight = null;
    }
  }

  void _scheduleLoadChildren() {
    _childrenDebounce?.cancel();
    _childrenDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadChildren();
    });
  }

  Future<void> _selectEstablishment(Map<String, dynamic> est) async {
    if (_loadingEstablishments || _loadingChildren) return;

    final subdomain = (est['id'] ?? '').toString();
    final name = (est['name'] ?? '').toString();
    if (subdomain.isEmpty) {
      return;
    }

    setState(() {
      _loadingEstablishments = true;
      _establishmentsError = null;
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
      final previousSubdomain = ctx.establishment?.subdomain;
      final previousYear = ctx.academicYear;
      ctx.setEstablishment(
        SelectedEstablishment(
          subdomain: subdomain,
          tenantId: tenantId,
          name: (estData['name'] ?? name).toString(),
          logo: estData['logo']?.toString(),
          city: estData['city']?.toString(),
        ),
      );

      if (previousSubdomain != subdomain) {
        setState(() {
          _availableYears = const [];
          _yearLabelToValue = const {};
        });
      }

      final accessToken = resp['access_token'];
      final refreshToken = resp['refresh_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        final authService = context.read<AuthService>();
        await authService.setTokens(
          accessToken: accessToken,
          refreshToken: refreshToken is String ? refreshToken : null,
        );
      }

      final yearsRaw = resp['years'];
      final Map<String, String> mapping = {};
      final List<String> labels = [];

      if (yearsRaw is List) {
        for (final item in yearsRaw) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final label = (m['label'] ?? m['annee'] ?? m['name'] ?? '')
                .toString()
                .trim();
            final value = (m['value'] ?? m['annee'] ?? label).toString().trim();
            if (label.isNotEmpty) {
              labels.add(label);
              mapping[label] = value.isNotEmpty ? value : label;
            }
          } else {
            final s = item.toString().trim();
            if (s.isNotEmpty) {
              labels.add(s);
              mapping[s] = s;
            }
          }
        }
      }

      final selectedYearRaw = (resp['selected_year'] ?? '').toString().trim();
      final selectedFromBackend = selectedYearRaw.isNotEmpty
          ? selectedYearRaw
          : (labels.isNotEmpty ? mapping[labels.first] : null);

      setState(() {
        _availableYears = labels;
        _yearLabelToValue = mapping;
      });

      final shouldPreserveYear =
          previousSubdomain == subdomain && (previousYear ?? '').isNotEmpty;
      if (shouldPreserveYear) {
        ctx.setAcademicYear(previousYear);
      } else {
        ctx.setAcademicYear(selectedFromBackend);
      }

      if (!mounted) return;
      setState(() {
        _childrenError = null;
      });
      _scheduleLoadChildren();
    } catch (e) {
      setState(() {
        _establishmentsError = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loadingEstablishments = false;
      });
    }
  }

  Future<void> _selectChild(Map<String, dynamic> child) async {
    if (_loadingChildren || _loadingEstablishments) return;

    final idRaw = child['id'];
    final id = idRaw is int ? idRaw : int.tryParse((idRaw ?? '').toString());
    if (id == null) return;

    final fullName = (child['full_name'] ?? '').toString();
    final className = (child['class_name'] ?? '').toString();

    final ctx = context.read<ParentContextProvider>();
    ctx.setChild(
      SelectedChild(
        id: id,
        fullName: fullName.isNotEmpty ? fullName : 'Élève $id',
        className: className.isNotEmpty ? className : null,
      ),
    );
  }

  Future<void> _openModule(String module) async {
    final parentCtx = context.read<ParentContextProvider>();

    if (!parentCtx.hasEstablishment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une école.')),
      );
      return;
    }

    if (!parentCtx.hasChild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un enfant.')),
      );
      return;
    }

    final route = switch (module) {
      'notes' => '/notes',
      'homework' => '/homework',
      'bulletins' => '/bulletins',
      'notifications' => '/notifications',
      'absences' => '/absences',
      'scolarites' => '/scolarites',
      _ => null,
    };

    if (route != null) {
      Navigator.of(context).pushNamed(route);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadEstablishments();
            final ctx = context.read<ParentContextProvider>();
            if (ctx.hasEstablishment) {
              await _loadChildren();
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.lg,
                    AppTheme.lg,
                    AppTheme.lg,
                    0,
                  ),
                  child: _buildHeroHeader(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEstablishmentsSection(context),
                      const SizedBox(height: AppTheme.lg),
                      _buildAcademicYearSection(context),
                      if (context
                          .watch<ParentContextProvider>()
                          .hasEstablishment)
                        const SizedBox(height: AppTheme.lg),
                      _buildChildrenSection(context),
                      const SizedBox(height: AppTheme.xl),
                      _buildSectionTitle(context, 'Modules'),
                      const SizedBox(height: AppTheme.md),
                      _buildFeaturesGrid(context),
                      const SizedBox(height: AppTheme.xl),
                      CustomButton(
                        label: 'Se déconnecter',
                        backgroundColor: AppTheme.errorColor,
                        onPressed: () => _handleLogout(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Consumer2<AuthProvider, ParentContextProvider>(
      builder: (context, authProvider, ctx, _) {
        final user = authProvider.currentUser;
        final firstName = (user?.fullName ?? 'Parent').split(' ').first;
        final school = ctx.establishment?.name;
        final child = ctx.child?.fullName;
        final year = ctx.academicYear;

        final contextLabel = [
          if (school != null && school.trim().isNotEmpty) school,
          if (year != null && year.trim().isNotEmpty) year,
          if (child != null && child.trim().isNotEmpty) child,
        ].join(' • ');

        final Color glowA = const Color(0xFF00E676);
        final Color glowB = const Color(0xFF00BFA5);

        Widget contextChip(IconData icon, String text) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white.withOpacity(0.92)),
                const SizedBox(width: AppTheme.sm),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      Color.lerp(AppTheme.primaryColor, glowB, 0.42)!,
                      Color.lerp(AppTheme.primaryColor, Colors.black, 0.25)!,
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
                      colors: [
                        glowA.withOpacity(0.35),
                        glowA.withOpacity(0.00),
                      ],
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
                      colors: [
                        glowB.withOpacity(0.30),
                        glowB.withOpacity(0.00),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
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
                                padding: const EdgeInsets.all(2.2),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.16),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      firstName.trim().isNotEmpty
                                          ? firstName
                                                .trim()
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : 'P',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tableau de bord',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.92),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bonjour $firstName',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.md,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCircle,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: glowA,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: glowA.withOpacity(0.55),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connecté',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.92),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.md),
                        Text(
                          'Suivi scolaire moderne et sécurisé',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.80),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: AppTheme.lg),
                        if ((school ?? '').trim().isNotEmpty ||
                            (year ?? '').trim().isNotEmpty ||
                            (child ?? '').trim().isNotEmpty)
                          Wrap(
                            spacing: AppTheme.sm,
                            runSpacing: AppTheme.sm,
                            children: [
                              if ((school ?? '').trim().isNotEmpty)
                                contextChip(Icons.school, school!.trim()),
                              if ((year ?? '').trim().isNotEmpty)
                                contextChip(Icons.event, year!.trim()),
                              if ((child ?? '').trim().isNotEmpty)
                                contextChip(Icons.person, child!.trim()),
                            ],
                          )
                        else
                          Text(
                            'Choisissez une école et un enfant pour accéder aux modules.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.75),
                                ),
                          ),
                        if (contextLabel.trim().isNotEmpty)
                          const SizedBox(height: AppTheme.sm),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ],
    );
  }

  Widget _buildEstablishmentsSection(BuildContext context) {
    return Consumer<ParentContextProvider>(
      builder: (context, parentCtx, _) {
        final current = parentCtx.establishment;
        final selectedSubdomain = current?.subdomain;

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [AppTheme.shadowSmall],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingEstablishments)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              if (_loadingEstablishments) const SizedBox(height: AppTheme.md),
              _sectionHeader(
                context,
                icon: Icons.school,
                title: 'Mes écoles',
                trailing: IconButton(
                  onPressed: _loadingEstablishments
                      ? null
                      : _scheduleLoadEstablishments,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: AppTheme.md),
              if (_establishmentsError != null)
                Text(
                  _establishmentsError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                )
              else if (_establishments.isEmpty)
                Text(
                  'Aucune école disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _establishments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppTheme.md),
                    itemBuilder: (context, index) {
                      final est = _establishments[index];
                      final name = (est['name'] ?? '').toString();
                      final logo = est['logo']?.toString();
                      final countRaw = est['children_count'];
                      final count = countRaw is int
                          ? countRaw
                          : int.tryParse((countRaw ?? '').toString());

                      final isSelected =
                          (est['id'] ?? '').toString() ==
                          (selectedSubdomain ?? '');

                      final hasLogo = (logo ?? '').trim().isNotEmpty;

                      return InkWell(
                        onTap: _loadingEstablishments || _loadingChildren
                            ? null
                            : () => _selectEstablishment(est),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: Opacity(
                          opacity: isSelected || selectedSubdomain == null
                              ? 1
                              : 0.55,
                          child: SizedBox(
                            width: 86,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? const [AppTheme.shadowSmall]
                                            : const [],
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor.withOpacity(
                                              isSelected ? 0.22 : 0.12,
                                            ),
                                            AppTheme.primaryColor.withOpacity(
                                              isSelected ? 0.10 : 0.04,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: hasLogo
                                            ? Image.network(
                                                logo!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.school,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.school,
                                                color: AppTheme.primaryColor,
                                              ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        left: -4,
                                        top: -4,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.surfaceColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (count != null)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.sm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  name.isNotEmpty ? name : 'École',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.sm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return Consumer<ParentContextProvider>(
      builder: (context, parentCtx, _) {
        if (!parentCtx.hasEstablishment) {
          return const SizedBox.shrink();
        }

        final selectedChildId = parentCtx.child?.id;

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [AppTheme.shadowSmall],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingChildren)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              if (_loadingChildren) const SizedBox(height: AppTheme.md),
              _sectionHeader(
                context,
                icon: Icons.person,
                title: 'Mes enfants',
                trailing: IconButton(
                  onPressed: _loadingChildren ? null : _loadChildren,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: AppTheme.md),
              if (_childrenError != null)
                Text(
                  _childrenError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                )
              else if (_children.isEmpty)
                Text(
                  'Aucun enfant',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _children.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppTheme.md),
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final idRaw = child['id'];
                      final id = idRaw is int
                          ? idRaw
                          : int.tryParse((idRaw ?? '').toString());
                      final fullName = (child['full_name'] ?? '').toString();
                      final photo =
                          (child['profile_picture'] ?? child['photo'] ?? '')
                              .toString();
                      final hasPhoto = photo.trim().isNotEmpty;

                      final isSelected = id != null && id == selectedChildId;

                      return InkWell(
                        onTap: _loadingChildren || _loadingEstablishments
                            ? null
                            : () => _selectChild(child),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: Opacity(
                          opacity: isSelected || selectedChildId == null
                              ? 1
                              : 0.55,
                          child: SizedBox(
                            width: 86,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? const [AppTheme.shadowSmall]
                                            : const [],
                                        color: isSelected
                                            ? AppTheme.primaryColor.withOpacity(
                                                0.18,
                                              )
                                            : AppTheme.primaryColor.withOpacity(
                                                0.08,
                                              ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: hasPhoto
                                            ? Image.network(
                                                photo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.person,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: AppTheme.primaryColor,
                                              ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        left: -4,
                                        top: -4,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.surfaceColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  fullName.isNotEmpty ? fullName : 'Enfant',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.sm),
            ],
          ),
        );
      },
    );
  }

  /// Construire la grille de fonctionnalités
  Widget _buildFeaturesGrid(BuildContext context) {
    final glowA = const Color(0xFF00E676);
    final glowB = const Color.fromARGB(255, 38, 105, 73);

    final features = [
      {
        'icon': Icons.calendar_today,
        'title': 'Emploi du temps',
        'description': 'Voir votre emploi du temps',
      },
      {
        'icon': Icons.grade,
        'title': 'Notes',
        'description': 'Consulter vos notes',
      },
      {
        'icon': Icons.assignment,
        'title': 'Devoirs',
        'description': 'Voir les devoirs',
      },
      {
        'icon': Icons.notifications,
        'title': 'Notifications',
        'description': 'Vos messages',
      },
      {
        'icon': Icons.insert_drive_file,
        'title': 'Bulletins',
        'description': 'Voir les bulletins',
      },
      {
        'icon': Icons.event_busy,
        'title': 'Absences',
        'description': 'Consulter les absences',
      },
      {
        'icon': Icons.payments,
        'title': 'Scolarités',
        'description': 'Voir les paiements',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.lg,
        mainAxisSpacing: AppTheme.lg,
        childAspectRatio: 1,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            onTap: () {
              if (feature['title'] == 'Emploi du temps') {
                _openTimetableFlow(context);
                return;
              }

              if (feature['title'] == 'Notes') {
                _openModule('notes');
                return;
              }

              if (feature['title'] == 'Devoirs') {
                _openModule('homework');
                return;
              }

              if (feature['title'] == 'Notifications') {
                _openModule('notifications');
                return;
              }

              if (feature['title'] == 'Bulletins') {
                _openModule('bulletins');
                return;
              }

              if (feature['title'] == 'Absences') {
                _openModule('absences');
                return;
              }

              if (feature['title'] == 'Scolarités') {
                _openModule('scolarites');
                return;
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              child: Stack(
                children: [
                  Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surfaceColor,
                          AppTheme.surfaceColor.withOpacity(0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      border: Border.all(
                        color: glowA.withOpacity(0.22),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowA.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        AppTheme.shadowSmall,
                      ],
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.lg),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXL,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
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
                                        padding: const EdgeInsets.all(2.2),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(
                                              0.10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.18,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            feature['icon'] as IconData,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.sm,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusCircle,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: AppTheme.textTertiaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.md),
                            Text(
                              feature['title'] as String,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.1,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.xs),
                            Text(
                              feature['description'] as String,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: LinearGradient(
                                        colors: [
                                          glowA.withOpacity(0.55),
                                          glowB.withOpacity(0.25),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openTimetableFlow(BuildContext context) {
    final ctx = context.read<ParentContextProvider>();

    if (!ctx.hasEstablishment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une école.')),
      );
      return;
    }

    if (!ctx.hasChild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un élève.')),
      );
      return;
    }

    Navigator.of(context).pushNamed('/timetable');
  }

  /// Gérer la déconnexion
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppTheme.xl),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.xl),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            boxShadow: const [AppTheme.shadowLarge],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.20),
                          AppTheme.primaryColor.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Text(
                      'Déconnexion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                'Êtes-vous sûr de vouloir vous déconnecter ?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.25),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.md,
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.md,
                        ),
                      ),
                      child: const Text('Déconnecter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
