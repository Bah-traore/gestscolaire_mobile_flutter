import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/app_theme.dart';

/// Widget pour afficher les statistiques de performance
class PerformanceStatsWidget extends StatefulWidget {
  final ApiService apiService;

  const PerformanceStatsWidget({
    super.key,
    required this.apiService,
  });

  @override
  State<PerformanceStatsWidget> createState() => _PerformanceStatsWidgetState();
}

class _PerformanceStatsWidgetState extends State<PerformanceStatsWidget> {
  Map<String, Map<String, dynamic>> _stats = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
    });

    try {
      final stats = widget.apiService.getPerformanceStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
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
              const Icon(Icons.speed, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.sm),
              Text(
                'Statistiques de Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_stats.isEmpty)
            Text(
              'Aucune statistique disponible',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            )
          else
            Column(
              children: _stats.entries.map((entry) {
                final endpoint = entry.key;
                final data = entry.value;
                final avg = data['avg']?.toDouble() ?? 0.0;
                final count = data['count'] ?? 0;
                
                Color statusColor = AppTheme.successColor;
                if (avg > 3000) {
                  statusColor = AppTheme.errorColor;
                } else if (avg > 1500) {
                  statusColor = AppTheme.warningColor;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.sm),
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: statusColor.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.xs),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Icon(
                              _getStatusIcon(avg),
                              size: 16,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: AppTheme.sm),
                          Expanded(
                            child: Text(
                              endpoint,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Moyenne',
                            '${avg.toStringAsFixed(0)}ms',
                            statusColor,
                          ),
                          _buildStatItem(
                            'Requêtes',
                            count.toString(),
                            AppTheme.textSecondaryColor,
                          ),
                          _buildStatItem(
                            'Min',
                            '${data['min']?.toString() ?? '-'}ms',
                            AppTheme.textSecondaryColor,
                          ),
                          _buildStatItem(
                            'Max',
                            '${data['max']?.toString() ?? '-'}ms',
                            AppTheme.textSecondaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(double avgMs) {
    if (avgMs > 3000) {
      return Icons.error;
    } else if (avgMs > 1500) {
      return Icons.warning;
    }
    return Icons.check_circle;
  }
}

/// Bouton pour optimiser les performances
class PerformanceOptimizationButton extends StatelessWidget {
  final ApiService apiService;
  final VoidCallback? onOptimized;

  const PerformanceOptimizationButton({
    super.key,
    required this.apiService,
    this.onOptimized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: () => _optimizePerformance(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.speed,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.sm),
                Text(
                  'Optimiser',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _optimizePerformance(BuildContext context) async {
    try {
      // Vider le cache
      apiService.clearCache();
      
      // Afficher un message de confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache vidé et performances optimisées'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      onOptimized?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'optimisation'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}