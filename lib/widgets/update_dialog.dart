import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onUpdate,
    required this.onLater,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  static const Color _glowA = Color(0xFF00E676);
  static const Color _glowB = Color(0xFF00BFA5);
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMandatory = widget.updateInfo.isMandatory;
    final primaryColor = isMandatory ? _glowA : colorScheme.primary;

    return WillPopScope(
      onWillPop: () async => !isMandatory,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec icône animée
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isMandatory
                            ? Icons.system_update
                            : Icons.system_update_alt,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Contenu
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isMandatory
                          ? 'Mise à jour requise'
                          : 'Nouvelle version disponible',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Version et taille
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.new_releases,
                            size: 20,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Version ${widget.updateInfo.version}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 1,
                            height: 16,
                            color: colorScheme.outline,
                          ),
                          Icon(
                            Icons.storage,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.updateInfo.formattedSize,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nouveautés
                    if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nouveautés',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[50]!,
                              const Color(0xFFE8F5E9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.updateInfo.releaseNotes,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    // Progression du téléchargement
                    if (_isDownloading) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'Téléchargement en cours...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                minHeight: 6,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  primaryColor,
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

              // Actions
              if (!_isDownloading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      if (!isMandatory)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onLater,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Plus tard',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      if (!isMandatory) const SizedBox(width: 12),
                      Expanded(
                        flex: isMandatory ? 2 : 1,
                        child: ElevatedButton(
                          onPressed: _handleUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMandatory
                                    ? Icons.download
                                    : Icons.download_for_offline,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  isMandatory ? 'Mettre à jour' : 'Télécharger',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final updateService = UpdateService();
      final filePath = await updateService.downloadUpdate(
        widget.updateInfo,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (filePath != null) {
        // Lancer l'installation automatique
        final installed = await updateService.installApk(filePath);

        setState(() {
          _isDownloading = false;
        });

        if (installed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: _glowA),
                    const SizedBox(width: 12),
                    const Text('Installation lancée...'),
                  ],
                ),
                backgroundColor: _glowB,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Installation automatique échouée, proposer l'installation manuelle
          if (mounted) {
            _showManualInstallDialog(filePath);
          }
        }

        widget.onUpdate();
      } else {
        setState(() {
          _isDownloading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Erreur lors du téléchargement'),
                ],
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur: $e')),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showManualInstallDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.install_mobile, color: _glowA),
            const SizedBox(width: 8),
            const Text('Installation manuelle'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'L\'installation automatique a échoué. Vous pouvez installer manuellement :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filePath,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Ouvrez votre gestionnaire de fichiers\n'
              '2. Allez dans le dossier ci-dessus\n'
              '3. Touchez le fichier APK pour installer',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
