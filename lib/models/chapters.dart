import 'package:on_device_ai/models/subtopics.dart';

class Chapters {
  final List<Subtopics> subtopics;

  Chapters({required this.subtopics});

  factory Chapters.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Chapters(subtopics: []);
    }
    return Chapters(subtopics: json['subtopics']);
  }
}
