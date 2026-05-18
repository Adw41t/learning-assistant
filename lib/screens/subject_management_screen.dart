import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/student.dart';
import 'package:on_device_ai/models/subject.dart';
import 'package:on_device_ai/screens/add_subject_modal.dart';
import 'package:on_device_ai/screens/setup_screen.dart';
import 'package:on_device_ai/services/gemma_service.dart';
import 'package:on_device_ai/utils/shared_preference_manager.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:on_device_ai/utils/subject_data.dart';

class SubjectManagementScreen extends StatefulWidget {
  final LocalDataSource localDataSource;
  final GemmaService gemmaService;
  const SubjectManagementScreen({
    super.key,
    required this.localDataSource,
    required this.gemmaService,
  });

  @override
  State<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  bool isGenerating = false;
  bool isExtracting = false;
  String error = '';
  late SharedPreferenceManager sharedPreferenceManager;

  Subject? subject;
  int chapterNumber = 0;
  int subTopic = 0;
  String? newSubjectName;
  Subject? newSubject;

  List<String> previousSubjects = [];

  Student? studentData;
  @override
  void initState() {
    super.initState();
    studentData = di<StudentData>().student;
    if (studentData == null) {
      getStudentDataFromCache();
    }
    previousSubjects.addAll(studentData?.subjects ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      sharedPreferenceManager = di<SharedPreferenceManager>();
    });
  }

  Future<void> getStudentDataFromCache() async {
    studentData = await widget.localDataSource.getDataFromLocalHiveDB<Student>(
      "student",
    );
  }

  // Triggers the accessible bottom sheet modal sheet form
  void _showAddSubjectModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to push up over the keyboard
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return AddSubjectFormModal(
          studentName: studentData?.name ?? 'studentName',
          localDataSource: widget.localDataSource,
          onSubjectAdded: (String newSubjectName, Subject newSubject) {
            this.newSubjectName = newSubjectName;
            this.newSubject = newSubject;
            cacheSubject(newSubjectName);
            setState(() {
              previousSubjects.insert(
                0,
                newSubjectName,
              ); // Prepend new subject to top
            });
            // if (newSubject.chapters.isNotEmpty) {
            //   if (newSubject.chapters.first.subtopics.isNotEmpty) {
            //     if (newSubject.chapters.first.subtopics.first.text != null) {
            //       summarizeText(newSubject.chapters.first.subtopics.first.text!);
            //     }
            //   }
            // }
          },
        );
      },
    );
  }

  Future<void> cacheSubject(String newSubject) async {
    di<StudentData>().setCurrentSubject(newSubject);
    di<StudentData>().addSubject(newSubject);
    if (studentData != null) {
      var subjects = studentData!.subjects;
      subjects.add(newSubject);
      Student student = Student(
        name: studentData!.name,
        classLevel: studentData!.classLevel,
        language: studentData!.language,
        subjects: subjects,
        disability: studentData!.disability,
      );
      await widget.localDataSource.addDataToLocalHiveDB("student", student);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bite-size Subjects'),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Option A: Add Subject Card
            Semantics(
              label:
                  'Double tap to create and configure a new study subject with files',
              button: true,
              child: Card(
                elevation: 2,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showAddSubjectModal(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 24.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 30),
                        SizedBox(width: 12),
                        Text(
                          'Add New Subject',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Option B: Header and List for Previously added subjects
            Text(
              'Previously Added Subjects',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Dynamic Accessible List of Subjects
            previousSubjects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No subjects added yet.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: previousSubjects.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final subject = previousSubjects[index];
                      return MergeSemantics(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          leading: const Icon(Icons.bookmark_outline),
                          title: Text(
                            subject,
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            checkIfSubjectTextAlreadyExtractedAndReturn(
                              subject,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> summarizeText(String text) async {
    try {
      String message =
          'Your total output must be concise and under 950 characters. Strictly No Profanity. You are a patient teacher. Use the given text and generate JSON containing learnings. Also generate another JSON containing 1 mcq with options and correct answer.  Output structure [{type:learnings,content:learnings},{type:quiz,question:question,options:[options],correctAnswer:correctAnswerIndex}]. Output only valid JSON. Do not include any text before JSON. Do not include any text after JSON. text - $text';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SetupScreen(
            gemmaService: widget.gemmaService,
            message: message,
            currentChapter: chapterNumber,
            currentSubTopic: subTopic,
            summarise: true,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      setState(() {
        error = '%%%%%%%Failed to summarise%%%%%%%%%%%';
      });
    }
  }

  Future<void> checkIfSubjectTextAlreadyExtractedAndReturn(
    String currentSubject,
  ) async {
    try {
      // if newly added subject matches selected subject, the use exisiting data instead of checking in db
      if ((newSubjectName != null && newSubject != null) &&
          currentSubject == newSubjectName) {
        subject = newSubject;
      } else {
        subject = await widget.localDataSource.getDataFromLocalHiveDB(
          "${studentData?.name ?? "studentName"}_$currentSubject",
        );
      }
      if (subject != null) {
        di<SubjectData>().setSubjectData(subject!);
        int? chapterNumberFromPref = (sharedPreferenceManager.getInt(
          "${studentData?.name ?? "studentName"}_${currentSubject}_chapter",
        ));
        if (chapterNumberFromPref != null) {
          chapterNumber = chapterNumberFromPref;
          int? subTopicFromPref = (sharedPreferenceManager.getInt(
            "${studentData?.name ?? "studentName"}_${currentSubject}_chapter_subtopic",
          ));
          if (subTopicFromPref != null) {
            subTopic = subTopicFromPref;
          }
        }
        if ((subject!.chapters.isNotEmpty &&
                subject!.chapters.length > chapterNumber) &&
            (subject!.chapters[chapterNumber].subtopics.isNotEmpty &&
                subject!.chapters[chapterNumber].subtopics.length > subTopic)) {
          String? text =
              subject?.chapters[chapterNumber].subtopics[subTopic].text;
          if (text != null && text.isNotEmpty) {
            summarizeText(text);
          }
        } else {
          setState(() {
            error = "text is null";
          });
        }
        di<StudentData>().setCurrentSubject(currentSubject);
      }
    } catch (e) {
      subject = null;
    }
  }
}
