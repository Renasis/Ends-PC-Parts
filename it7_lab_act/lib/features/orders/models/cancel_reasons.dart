/// The reasons a customer can pick when cancelling an order.
///
/// The text of the chosen reason is saved as-is in `cancellationReason`, so
/// the admin web shows it without any change.
class CancelReasons {
  CancelReasons._();

  /// The "Other" choice asks the customer to type their own reason.
  static const other = 'Other';

  static const presets = <String>[
    'Changed my mind',
    'Ordered by mistake',
    'Found a better price elsewhere',
    'Wrong item or specs selected',
    'Need to change delivery address',
    'Need to change payment method',
    'Delivery will take too long',
    other,
  ];

  /// Longest custom reason accepted.
  static const maxOtherLength = 200;
}
