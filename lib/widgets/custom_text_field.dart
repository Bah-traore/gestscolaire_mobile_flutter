import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Champ de texte personnalisé
class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final bool readOnly;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final EdgeInsets contentPadding;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final int? maxLength;
  final bool showCounter;

  const CustomTextField({
    Key? key,
    this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.readOnly = false,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.backgroundColor,
    this.borderColor,
    this.focusedBorderColor,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppTheme.lg,
      vertical: AppTheme.md,
    ),
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.maxLength,
    this.showCounter = false,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }



  @override
  Widget build(BuildContext context) {
    // Toujours utiliser le suffixIcon fourni ou le toggle automatique
    final canToggleObscure =
        widget.obscureText && widget.onSuffixIconPressed == null && widget.suffixIcon == null;

    final IconData? effectiveSuffixIcon;
    if (widget.suffixIcon != null) {
      effectiveSuffixIcon = widget.suffixIcon;
    } else if (canToggleObscure) {
      effectiveSuffixIcon = _obscureText ? Icons.visibility_off : Icons.visibility;
    } else {
      effectiveSuffixIcon = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.sm),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: _obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          textCapitalization: widget.textCapitalization,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: widget.backgroundColor ?? AppTheme.surfaceColor,
            contentPadding: widget.contentPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: widget.borderColor ?? AppTheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: widget.borderColor ?? AppTheme.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide(
                color: widget.focusedBorderColor ?? AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppTheme.textSecondaryColor)
                : null,
            suffixIcon: effectiveSuffixIcon != null
                ? IconButton(
                    onPressed: widget.enabled
                        ? (widget.onSuffixIconPressed ??
                              (canToggleObscure ? () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              } : null))
                        : null,
                    icon: Icon(
                      effectiveSuffixIcon,
                      color: AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  )
                : null,
            counterText: widget.showCounter ? null : '',
          ),
        ),
      ],
    );
  }
}

/// Champ de mot de passe personnalisé
class PasswordField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const PasswordField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = true;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: PasswordField build - _obscureText = $_obscureText');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.sm),
        ],
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          obscureText: _obscureText,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: AppTheme.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
            ),
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor),
            suffixIcon: IconButton(
              onPressed: () {
                print('DEBUG: IconButton pressed - avant: $_obscureText');
                _togglePasswordVisibility();
                print('DEBUG: IconButton pressed - après: $_obscureText');
              },
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Champ email personnalisé
class EmailField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const EmailField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label ?? 'Email',
      hint: hint ?? 'Entrez votre email',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: validator ?? _validateEmail,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefixIcon: Icons.email_outlined,
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer une adresse email valide';
    }

    return null;
  }
}

/// Champ téléphone personnalisé
class PhoneField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const PhoneField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label ?? 'Téléphone',
      hint: hint ?? '+223 XX XX XX XX',
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: validator ?? _validatePhone,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefixIcon: Icons.phone_outlined,
    );
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }

    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'\s'), ''))) {
      return 'Veuillez entrer un numéro de téléphone valide';
    }

    return null;
  }
}
