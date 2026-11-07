/// Small built-in lookup so the form can suggest a ZIP code.
///
/// It only covers the towns of Rizal (the store's default province). A
/// suggestion is never forced on the customer: the ZIP field stays editable,
/// and any other province simply gets no suggestion.
///
/// To cover more places, add entries to a new map and extend [zipFor].
class PhLocations {
  PhLocations._();

  static const rizalProvince = 'Rizal';

  /// Town -> ZIP code, in the order shown in the city suggestions.
  static const Map<String, String> rizalZipCodes = {
    'Angono': '1930',
    'Antipolo': '1870',
    'Baras': '1970',
    'Binangonan': '1940',
    'Cainta': '1900',
    'Cardona': '1950',
    'Jala-Jala': '1990',
    'Morong': '1960',
    'Pililla': '1910',
    'Rodriguez (Montalban)': '1860',
    'San Mateo': '1850',
    'Tanay': '1980',
    'Taytay': '1920',
    'Teresa': '1880',
  };

  static List<String> get rizalTowns => rizalZipCodes.keys.toList();

  /// Other spellings people type for the same town.
  static const Map<String, String> _aliases = {
    'montalban': 'rodriguez',
    'jalajala': 'jala-jala',
    'jala jala': 'jala-jala',
  };

  static final Map<String, String> _byKey = {
    for (final e in rizalZipCodes.entries) _normalize(e.key): e.value,
  };

  /// "City of Antipolo", "Antipolo City" and " antipolo " all become "antipolo".
  static String _normalize(String value) {
    var text = value.toLowerCase();
    text = text.replaceAll(RegExp(r'\(.*?\)'), ' ');
    text = text.replaceAll(RegExp(r'\b(city|municipality)\s+of\b'), ' ');
    text = text.replaceAll(RegExp(r'\bcity\b'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _aliases[text] ?? text;
  }

  static bool isRizal(String province) =>
      _normalize(province) == _normalize(rizalProvince);

  /// The ZIP code for [city] in [province], or null when it is not known.
  static String? zipFor(String city, String province) {
    if (!isRizal(province)) return null;
    return _byKey[_normalize(city)];
  }
}
