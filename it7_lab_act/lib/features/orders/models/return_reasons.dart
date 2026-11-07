/// The reasons a customer can pick when asking for a return.
///
/// The chosen text is saved as-is in `returnReason`.
class ReturnReasons {
  ReturnReasons._();

  static const other = 'Other';

  static const presets = <String>[
    'Item arrived damaged',
    'Item is defective or not working',
    'Wrong item received',
    'Item not as described',
    'Missing parts or accessories',
    'Changed my mind',
    other,
  ];
}
