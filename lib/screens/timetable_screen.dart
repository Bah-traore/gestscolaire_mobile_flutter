import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/timetable_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;
import '../models/timetable_models.dart';

enum TimetableViewMode { week, list }

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  TimetableViewMode _mode = TimetableViewMode.week;
  DateTime _weekStart = _startOfWeek(DateTime.now());

  bool _loading = false;
  String? _error;

  TimetableResponse? _data;
  bool _initialized = false;

  static DateTime _startOfWeek(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
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
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
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

      final resp = await timetableService.fetchTimetable(
        tenantId: tenantId,
        eleveId: eleveId,
        start: _weekStart,
        end: _weekEnd,
        view: 'week',
      );

      setState(() {
        _data = resp;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
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
              Navigator.of(context).pushReplacementNamed('/select-establishment');
            },
            child: const Text('Changer d\'école'),
          ),
          IconButton(
            tooltip: _mode == TimetableViewMode.week ? 'Liste' : 'Semaine',
            onPressed: () {
              setState(() {
                _mode = _mode == TimetableViewMode.week
                    ? TimetableViewMode.list
                    : TimetableViewMode.week;
              });
            },
            icon: Icon(
              _mode == TimetableViewMode.week ? Icons.list : Icons.view_week,
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
          Row(
            children: [
              Expanded(
                child: Consumer<ParentContextProvider>(
                  builder: (context, ctx, _) {
                    final est = ctx.establishment;
                    final child = ctx.child;
                    final label = [
                      if (est != null) est.name,
                      if (child != null) child.fullName,
                    ].join(' • ');

                    return InkWell(
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/select-child');
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Text(
                                label.isNotEmpty ? label : 'Choisir un enfant',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
