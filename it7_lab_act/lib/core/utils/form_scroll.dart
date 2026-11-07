import 'package:flutter/material.dart';

/// Validates [formKey]. When a field is invalid, scrolls it into view and
/// returns false, so the customer sees what is missing even when it is far
/// above the button they just pressed.
bool validateAndScrollToError(GlobalKey<FormState> formKey) {
  final form = formKey.currentState;
  if (form == null) return false;
  if (form.validate()) return true;

  BuildContext? firstInvalid;
  void visit(Element element) {
    if (firstInvalid != null) return;
    if (element is StatefulElement) {
      final state = element.state;
      if (state is FormFieldState && state.hasError) {
        firstInvalid = element;
        return;
      }
    }
    element.visitChildren(visit);
  }

  (formKey.currentContext as Element?)?.visitChildren(visit);

  final target = firstInvalid;
  if (target != null) {
    Scrollable.ensureVisible(
      target,
      alignment: 0.15,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }
  return false;
}
