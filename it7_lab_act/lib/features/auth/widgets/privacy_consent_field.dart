import 'package:flutter/material.dart';

import 'privacy_policy_sheet.dart';

/// "I understand and agree to the Privacy Policy" checkbox for the sign-up
/// form. Part of the [Form], so `validate()` fails until it is ticked.
class PrivacyConsentField extends FormField<bool> {
  PrivacyConsentField({
    super.key,
    super.enabled,
    ValueChanged<bool>? onChanged,
  }) : super(
          initialValue: false,
          validator: (accepted) => accepted == true
              ? null
              : 'You must accept the Privacy Policy to create an account.',
          builder: (state) {
            final theme = Theme.of(state.context);
            final scheme = theme.colorScheme;

            void toggle(bool? value) {
              state.didChange(value ?? false);
              onChanged?.call(value ?? false);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: state.value ?? false,
                      onChanged: enabled ? toggle : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            GestureDetector(
                              onTap: enabled
                                  ? () => toggle(!(state.value ?? false))
                                  : null,
                              child: const Text(
                                'I understand and agree to the ',
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  PrivacyPolicySheet.show(state.context),
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      state.errorText!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            );
          },
        );
}
