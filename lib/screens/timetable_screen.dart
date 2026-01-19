import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/children_service.dart';
import '../services/establishments_service.dart';
import '../services/timetable_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;
import '../models/timetable_models.dart';
import '../utils/user_friendly_errors.dart';
import 'package:dio/dio.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

enum TimetableViewMode { week, list, agenda }

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _loading = false;
  String? _error;

  bool _refreshing = false;
  Timer? _estDebounce;
  Timer? _childDebounce;

  TimetableViewMode _mode = TimetableViewMode.week;
  DateTime _weekStart = _startOfWeek(DateTime.now());

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  TimetableResponse? _data;
  TimetableResponse? _agendaData;
  bool _initialized = false;

  List<Map<String, dynamic>> _availableEstablishments = const [];
  List<Map<String, dynamic>> _availableChildren = const [];
  bool _loadingSelector = false;

  static DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  @override
  void dispose() {
    _estDebounce?.cancel();
    _childDebounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    if (!mounted) return;
    if (_agendaData != null || _data != null) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }
    _loadAgendaMonth(_focusedDay);
    _load();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _parseLocal(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt?.toLocal();
  }

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime _endOfMonth(DateTime d) {
    final firstNext = (d.month == 12)
        ? DateTime(d.year + 1, 1, 1)
        : DateTime(d.year, d.month + 1, 1);
    return firstNext.subtract(const Duration(days: 1));
  }

  Widget _buildAgendaView(BuildContext context) {
    final events = _agendaData?.events ?? const <TimetableEvent>[];
    final Map<DateTime, List<TimetableEvent>> byDay = {};
    for (final e in events) {
      final dt = _parseLocal(e.start);
      final key = dt == null ? _dateOnly(_focusedDay) : _dateOnly(dt);
      byDay.putIfAbsent(key, () => []).add(e);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    final selected = _selectedDay ?? _dateOnly(_focusedDay);
    final dayEvents = byDay[selected] ?? const <TimetableEvent>[];

    return Column(
      children: [
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
          child: TableCalendar<TimetableEvent>(
            locale: 'fr_FR',
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) =>
                _selectedDay != null && isSameDay(_selectedDay, d),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            eventLoader: (day) => byDay[_dateOnly(day)] ?? const [],
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = _dateOnly(selectedDay);
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) async {
              setState(() {
                _focusedDay = focusedDay;
              });
              await _loadAgendaMonth(focusedDay);
            },
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? Center(
                  child: Text(
                    'Aucun cours ce jour.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  itemCount: dayEvents.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.md),
                  itemBuilder: (context, index) {
                    final e = dayEvents[index];
                    return _eventCard(context, e);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _loadAgendaMonth(DateTime focused) async {
    setState(() {
      _refreshing = _agendaData != null;
      _loading = _agendaData == null;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final timetableService = TimetableService(api);
      final ctx = context.read<ParentContextProvider>();
      final tenantId = ctx.establishment?.tenantId;
      final eleveId = ctx.child?.id;
      if (tenantId == null) {
        throw Exception('Veuillez sélectionner une école');
      }
      if (eleveId == null) {
        throw Exception('Veuillez sélectionner un enfant');
      }

      final start = _startOfMonth(focused);
      final end = _endOfMonth(focused);

      TimetableResponse resp;
      try {
        resp = await timetableService
            .fetchTimetable(
              tenantId: tenantId,
              eleveId: eleveId,
              start: start,
              end: end,
              view: 'month',
            )
            .timeout(const Duration(seconds: 15));
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (refreshed) {
            resp = await timetableService
                .fetchTimetable(
                  tenantId: tenantId,
                  eleveId: eleveId,
                  start: start,
                  end: end,
                  view: 'month',
                )
                .timeout(const Duration(seconds: 15));
          } else {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            setState(() {
              _error = 'Votre session a expiré. Veuillez vous reconnecter.';
            });
            return;
          }
        } else {
          rethrow;
        }
      }

      setState(() {
        _agendaData = resp;
      });
    } catch (e) {
      setState(() {
        _error = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_initialized) return;
    _initialized = true;
    _selectedDay = _dateOnly(_focusedDay);
    await _loadSelectorData();
    await _loadAgendaMonth(_focusedDay);
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
      await _loadAgendaMonth(_focusedDay);
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

    await _loadAgendaMonth(_focusedDay);
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
      final timetableService = TimetableService(api);
      final ctx = context.read<ParentContextProvider>();
      final tenantId = ctx.establishment?.tenantId;
      final eleveId = ctx.child?.id;
      if (tenantId == null) {
        throw Exception('Veuillez sélectionner une école');
      }
      if (eleveId == null) {
        throw Exception('Veuillez sélectionner un enfant');
      }

      TimetableResponse resp;
      try {
        resp = await timetableService.fetchTimetable(
          tenantId: tenantId,
          eleveId: eleveId,
          start: _weekStart,
          end: _weekEnd,
          view: 'week',
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (refreshed) {
            resp = await timetableService.fetchTimetable(
              tenantId: tenantId,
              eleveId: eleveId,
              start: _weekStart,
              end: _weekEnd,
              view: 'week',
            );
          } else {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            setState(() {
              _error = 'Votre session a expiré. Veuillez vous reconnecter.';
            });
            return;
          }
        } else {
          rethrow;
        }
      }

      setState(() {
        _data = resp;
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

  Future<void> _previousWeek() async {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
    await _load();
  }

  Future<void> _nextWeek() async {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Emploi du temps'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
            child: const Text('Changer d\'école'),
          ),
          IconButton(
            tooltip: _mode == TimetableViewMode.week
                ? 'Liste'
                : (_mode == TimetableViewMode.list ? 'Agenda' : 'Semaine'),
            onPressed: () {
              setState(() {
                _mode = _mode == TimetableViewMode.week
                    ? TimetableViewMode.list
                    : (_mode == TimetableViewMode.list
                          ? TimetableViewMode.agenda
                          : TimetableViewMode.week);
              });
            },
            icon: Icon(
              _mode == TimetableViewMode.week
                  ? Icons.list
                  : (_mode == TimetableViewMode.list
                        ? Icons.view_agenda
                        : Icons.view_week),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final rangeLabel =
        '${_weekStart.day}/${_weekStart.month} - ${_weekEnd.day}/${_weekEnd.month}';

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          Row(children: [Expanded(child: _buildContextDropdowns(context))]),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : _previousWeek,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    rangeLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _nextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
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

    if (_mode == TimetableViewMode.agenda) {
      return _buildAgendaView(context);
    }

    final events = _data?.events ?? const <TimetableEvent>[];
    if (events.isEmpty) {
      return Center(
        child: Text(
          'Aucun cours pour cette période.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (_mode == TimetableViewMode.list) {
      return _buildListView(context, events);
    }

    return _buildWeekView(context, events);
  }

  Widget _buildListView(BuildContext context, List<TimetableEvent> events) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.lg),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
      itemBuilder: (context, index) {
        final e = events[index];
        return _eventCard(context, e);
      },
    );
  }

  Widget _buildWeekView(BuildContext context, List<TimetableEvent> events) {
    // vue simple: groupement par jour
    final Map<String, List<TimetableEvent>> byDay = {};
    for (final e in events) {
      final date = DateTime.tryParse(e.start);
      final key = date == null
          ? 'Jour'
          : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(e);
    }

    final keys = byDay.keys.toList();
    keys.sort();

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.lg),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final day = keys[index];
        final items = byDay[day] ?? const <TimetableEvent>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.sm),
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.sm),
                  child: _eventCard(context, e),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventCard(BuildContext context, TimetableEvent e) {
    final start = DateTime.tryParse(e.start);
    final end = DateTime.tryParse(e.end);
    final timeLabel = (start != null && end != null)
        ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
        : '';

    final absent = e.enseignantAbsent == true;

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [AppTheme.shadowSmall],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: absent ? AppTheme.errorColor : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.matiere ?? e.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.xs),
                if (timeLabel.isNotEmpty)
                  Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppTheme.xs),
                if ((e.enseignant ?? '').isNotEmpty)
                  Text(
                    e.enseignant!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if ((e.room ?? '').isNotEmpty)
                  Text(
                    'Salle: ${e.room}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (absent)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.xs),
                    child: Text(
                      'Enseignant absent${(e.remplacant ?? '').isNotEmpty ? ' • Remplaçant: ${e.remplacant}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
