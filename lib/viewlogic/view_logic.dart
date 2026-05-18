import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/subject.dart';
import 'package:on_device_ai/utils/subject_data.dart';

class ViewLogic {
  final SubjectData subjectData;

  Subject? subject = di<SubjectData>().subject;

  ViewLogic({required this.subjectData});

  List<int> calculateNextChapterAndSubtopic(
    int currentChapter,
    int currentSubtopic,
  ) {
    int subTopicNumber = currentSubtopic;
    int chapterNumber = currentChapter;
    List<int> result = [currentChapter, currentSubtopic];
    if (subject != null) {
      if (subTopicNumber + 1 <
          subject!.chapters[chapterNumber].subtopics.length) {
        subTopicNumber = subTopicNumber + 1;
      } else {
        if (chapterNumber + 1 < subject!.chapters.length) {
          chapterNumber = chapterNumber + 1;
          subTopicNumber = 0;
        }
      }
      result = [];
      result.add(chapterNumber);
      result.add(subTopicNumber);
    }
    return result;
  }

  String cleanJson(String result) {
    result = result.trim();
    if (result.contains('```json')) {
      result = result.replaceFirst('```json', '```');
      int start = result.indexOf('```') + 3;
      int last = result.lastIndexOf('```') - 1;
      if (start > -1 && last > -1 && start != last) {
        result = result.substring(start, last);
      }
    } else if (result.contains('```')) {
      result = result.replaceAll('```', '');
    }
    // if (result.endsWith('```')) {
    //   result = result.substring(0, result.length - 3);
    // }
    if (result.contains('`')) {
      result = result.replaceAll('`', '');
    }
    result = result.trim();
    return result;
  }
}
