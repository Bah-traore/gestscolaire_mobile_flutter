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

enum ModuleKind { notes, homework, bulletins, notifications, scolarites }

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
}
