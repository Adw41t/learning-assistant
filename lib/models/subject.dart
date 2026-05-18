import 'package:on_device_ai/models/chapters.dart';

class Subject {
  final String name;
  final List<Chapters> chapters;

  Subject({required this.name, required this.chapters});

  factory Subject.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Subject(name: '', chapters: []);
    }
    return Subject(name: json['name'], chapters: json['chapters']);
  }
}
