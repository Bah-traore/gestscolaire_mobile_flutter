import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/children_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart' as custom;
import '../utils/user_friendly_errors.dart';

class SelectChildScreen extends StatefulWidget {
  const SelectChildScreen({super.key});

  @override
  State<SelectChildScreen> createState() => _SelectChildScreenState();
}

class _SelectChildScreenState extends State<SelectChildScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = const [];

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
      final ctx = context.read<ParentContextProvider>();
      final est = ctx.establishment;
      if (est == null) {
        throw Exception('Veuillez choisir une école');
      }

      final api = context.read<ApiService>();
      final service = ChildrenService(api);

      final items = await service.fetchChildren(establishmentId: est.subdomain);
      setState(() {
        _children = items;
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

  Future<void> _select(Map<String, dynamic> child) async {
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

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/timetable');
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<ParentContextProvider>();
    final est = ctx.establishment;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Choisir un enfant'),
        bottom: est == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: Text(
                    est.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget())
          : _error != null
          ? Center(
              child: custom.ErrorWidget(message: _error!, onRetry: _load),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppTheme.lg),
              itemCount: _children.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
              itemBuilder: (context, index) {
                final child = _children[index];
                final fullName = (child['full_name'] ?? '').toString();
                final className = (child['class_name'] ?? '').toString();

                return InkWell(
                  onTap: () => _select(child),
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
                            Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isNotEmpty ? fullName : 'Enfant',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (className.isNotEmpty)
                                Text(
                                  className,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
