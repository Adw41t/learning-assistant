class Student {
  final String name;
  final String classLevel;
  final String language;
  final String disability;
  final List<String> subjects;

  Student({
    required this.name,
    required this.classLevel,
    required this.language,
    required this.subjects,
    required this.disability,
  });

  factory Student.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Student(
        name: "",
        classLevel: "",
        language: "",
        disability: "",
        subjects: [],
      );
    }
    return Student(
      name: json['name'],
      classLevel: json['classLevel'],
      disability: json['disability'],
      language: json['language'],
      subjects: json['subjects'],
    );
  }
}
