import 'package:on_device_ai/models/student.dart';

class StudentData {
  String? name;
  String? classLevel;
  String? language;
  String? disability;
  String? currentSubject;
  List<String> subjects = [];
  Student? student;

  void setName(String name) {
    this.name = name;
  }

  void setStudent(Student student) {
    this.student = student;
  }

  void setClassLevel(String classLevel) {
    classLevel = classLevel;
  }

  void setLanguage(String language) {
    language = language;
  }

  void setCurrentSubject(String currentSubject) {
    currentSubject = currentSubject;
  }

  void setDisability(String disability) {
    disability = disability;
  }

  void addSubjects(List<String> subjects) {
    this.subjects.addAll(subjects);
  }

  void addSubject(String subject) {
    subjects.add(subject);
  }

  void clear() {
    name = null;
    subjects = [];
    currentSubject = null;
    language = null;
    classLevel = null;
    disability = null;
  }
}
