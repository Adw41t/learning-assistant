class Subtopics {
  final String? text;

  Subtopics({required this.text});

  factory Subtopics.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Subtopics(text: null);
    }
    return Subtopics(text: json['text']);
  }
}
