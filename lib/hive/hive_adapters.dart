import 'package:hive_ce/hive.dart';
import 'package:on_device_ai/models/chapters.dart';
import 'package:on_device_ai/models/performance.dart';
import 'package:on_device_ai/models/student.dart';
import 'package:on_device_ai/models/subject.dart';
import 'package:on_device_ai/models/subject_generated_text.dart';
import 'package:on_device_ai/models/subtopics.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<Performance>(),
  AdapterSpec<Student>(),
  AdapterSpec<Subject>(),
  AdapterSpec<Chapters>(),
  AdapterSpec<Subtopics>(),
  AdapterSpec<SubjectGeneratedText>(),
], firstTypeId: 1)
class HiveAdapters {}
