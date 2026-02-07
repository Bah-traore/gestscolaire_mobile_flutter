import 'package:flutter/material.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';

class UpdateNotificationBanner extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDismiss;

  const UpdateNotificationBanner({
    super.key,
    required this.updateInfo,
    required this.onDismiss,
  });

  @override
  State<UpdateNotificationBanner> createState() =>
      _UpdateNotificationBannerState();
}

class _UpdateNotificationBannerState extends State<UpdateNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  static const Color _glowA = Color(0xFF00E676);
  static const Color _glowB = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();

    // Animation pulsante continue pour attirer l'attention
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _controller.repeat(
          reverse: true,
          period: const Duration(milliseconds: 2000),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _showUpdateDetails() {
    showDialog(
      context: context,
      barrierDismissible: !widget.updateInfo.isMandatory,
      builder: (context) => UpdateDialog(
        updateInfo: widget.updateInfo,
        onUpdate: () {
          Navigator.of(context).pop();
          _dismiss();
        },
        onLater: () {
          Navigator.of(context).pop();
          if (!widget.updateInfo.isMandatory) {
            _dismiss();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.updateInfo.isMandatory;
    final primaryColor = isMandatory
        ? _glowA
        : Theme.of(context).colorScheme.primary;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _pulseAnimation.value, child: child);
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showUpdateDetails,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icône animée
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMandatory
                              ? Icons.system_update
                              : Icons.new_releases,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Contenu texte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isMandatory
                                        ? 'Mise à jour requise'
                                        : 'Nouvelle version disponible',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMandatory)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Obligatoire',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version ${widget.updateInfo.version} • ${widget.updateInfo.formattedSize}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Bouton action
                      if (!isMandatory)
                        IconButton(
                          onPressed: _dismiss,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      // Flèche ou bouton
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher la bannière de mise à jour en overlay
class UpdateNotificationOverlay extends StatefulWidget {
  final Widget child;

  const UpdateNotificationOverlay({super.key, required this.child});

  @override
  State<UpdateNotificationOverlay> createState() =>
      _UpdateNotificationOverlayState();
}

class _UpdateNotificationOverlayState extends State<UpdateNotificationOverlay> {
  UpdateInfo? _updateInfo;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    // Attendre que l'app soit prête
    await Future.delayed(const Duration(seconds: 3));

    final updateService = UpdateService();
    await updateService.init();
    final updateInfo = await updateService.checkForUpdates();

    if (updateInfo != null && mounted) {
      setState(() {
        _updateInfo = updateInfo;
        _showBanner = true;
      });
    }
  }

  void _dismissBanner() {
    setState(() {
      _showBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner && _updateInfo != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: UpdateNotificationBanner(
                updateInfo: _updateInfo!,
                onDismiss: _dismissBanner,
              ),
            ),
          ),
      ],
    );
  }
}
