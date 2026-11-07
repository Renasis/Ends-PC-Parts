import 'package:flutter/material.dart';

/// What kind of place an address is. Shown as a small tag on the address card
/// so the customer (and the rider) can tell Home from Work at a glance.
enum AddressLabel {
  home('Home', Icons.home_outlined),
  work('Work', Icons.work_outline),
  other('Other', Icons.place_outlined);

  final String text;
  final IconData icon;

  const AddressLabel(this.text, this.icon);

  /// Value stored in the database (`home`, `work`, `other`).
  String get key => name;

  /// Reads a stored value. Anything unknown (or missing) becomes [home].
  static AddressLabel fromKey(Object? value) {
    final key = value?.toString().toLowerCase().trim();
    for (final label in values) {
      if (label.name == key) return label;
    }
    return AddressLabel.home;
  }
}
