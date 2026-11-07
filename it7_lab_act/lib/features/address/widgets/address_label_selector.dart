import 'package:flutter/material.dart';

import '../models/address_label.dart';

/// Home / Work / Other chips for tagging an address.
class AddressLabelSelector extends StatelessWidget {
  final AddressLabel value;
  final ValueChanged<AddressLabel> onChanged;

  const AddressLabelSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in AddressLabel.values)
          ChoiceChip(
            showCheckmark: false,
            avatar: Icon(label.icon, size: 18),
            label: Text(label.text),
            selected: label == value,
            onSelected: (_) => onChanged(label),
          ),
      ],
    );
  }
}
