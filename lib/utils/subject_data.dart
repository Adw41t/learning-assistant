import 'package:on_device_ai/models/subject.dart';

class SubjectData {
  Subject? subject;
  int? nextChapter;
  int? nextSubtopic;
  void setSubjectData(Subject subject) {
    this.subject = subject;
  }

  void setNextChapter(int chapter) {
    nextChapter = chapter;
  }

  void setNextSubtopic(int subtopic) {
    nextSubtopic = subtopic;
  }

  void clear() {
    subject = null;
    nextSubtopic = null;
    nextChapter = null;
  }
}
