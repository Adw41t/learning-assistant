class SubjectGeneratedText {
  final String id;
  final String generatedText;
  SubjectGeneratedText({required this.id, required this.generatedText});

  factory SubjectGeneratedText.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SubjectGeneratedText(id: "", generatedText: "");
    }
    return SubjectGeneratedText(
      id: json['id'],
      generatedText: json['generatedText'],
    );
  }
}
