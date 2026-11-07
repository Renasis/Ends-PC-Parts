/// A page of legal text: a title and titled paragraphs.
class LegalDocument {
  final String title;
  final String intro;
  final List<(String, String)> sections;

  const LegalDocument({
    required this.title,
    this.intro = '',
    required this.sections,
  });
}
