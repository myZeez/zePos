import 'package:flutter/material.dart';
import 'package:zepos/core/constants/build_identity.dart';
import 'package:zepos/ui/widgets/brand_lockup.dart';
import 'package:zepos/ui/widgets/form_field_group.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: ZeRadius.panel,
                border: Border.all(color: ZeColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLockup(compact: false),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: ZeColors.subtle, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  child,
                  const SizedBox(height: ZeSpace.md),
                  // The maker's mark, kept quiet: it belongs on the way in,
                  // not in the middle of serving a customer.
                  Center(
                    child: Text(
                      BuildIdentity.watermark,
                      style: ZeText.meta.copyWith(color: ZeColors.subtle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) => FormFieldGroup(
    label: label,
    child: TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(suffixIcon: suffixIcon),
    ),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    ),
  );
}
