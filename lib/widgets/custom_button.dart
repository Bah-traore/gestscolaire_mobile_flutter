import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Bouton personnalisé principal
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isOutlined;
  final EdgeInsets padding;
  
  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isOutlined = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTheme.lg),
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final button = isOutlined ? _buildOutlinedButton() : _buildElevatedButton();
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: button,
    );
  }
  
  Widget _buildElevatedButton() {
    return ElevatedButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        foregroundColor: textColor ?? Colors.white,
        disabledBackgroundColor: AppTheme.textHintColor,
        disabledForegroundColor: AppTheme.textTertiaryColor,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  textColor ?? Colors.white,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppTheme.sm),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: backgroundColor ?? AppTheme.primaryColor,
        disabledForegroundColor: AppTheme.textTertiaryColor,
        side: BorderSide(
          color: isEnabled
              ? (backgroundColor ?? AppTheme.primaryColor)
              : AppTheme.textHintColor,
        ),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  backgroundColor ?? AppTheme.primaryColor,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppTheme.sm),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Bouton flottant personnalisé
class CustomFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  
  const CustomFloatingActionButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      tooltip: tooltip,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? Colors.white,
                ),
              ),
            )
          : Icon(icon),
    );
  }
}

/// Bouton avec icône
class IconButton2 extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final Color? color;
  final double size;
  final bool isLoading;
  
  const IconButton2({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.color,
    this.size = 24,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLoading
              ? SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      color ?? AppTheme.primaryColor,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: color ?? AppTheme.primaryColor,
                  size: size,
                ),
          if (label != null) ...[
            const SizedBox(height: AppTheme.xs),
            Text(
              label!,
              style: TextStyle(
                color: color ?? AppTheme.primaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
