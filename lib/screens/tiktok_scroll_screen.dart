import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/subject.dart';
import 'package:on_device_ai/models/subject_generated_text.dart';
import 'package:on_device_ai/screens/chat_screen.dart';
import 'package:on_device_ai/services/gemma_service.dart';
import 'package:on_device_ai/services/performance_monitor.dart';
import 'package:on_device_ai/utils/shared_preference_manager.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:on_device_ai/utils/subject_data.dart';
import 'package:on_device_ai/viewlogic/view_logic.dart';

class TikTokScrollScreen extends StatefulWidget {
  final String jsonInput;
  final GemmaService gemmaService;
  final int? nextChapter;
  final int? nextSubTopic;

  const TikTokScrollScreen({
    super.key,
    required this.jsonInput,
    required this.gemmaService,
    this.nextChapter,
    this.nextSubTopic,
  });

  @override
  State<TikTokScrollScreen> createState() => _TikTokScrollScreenState();
}

class _TikTokScrollScreenState extends State<TikTokScrollScreen> {
  late StudentData student;
  String? studentName;
  String? subjectName;
  final List<Color> colors = [
    Colors.teal,
    Colors.red,
    Colors.deepPurpleAccent,
    Colors.blue,
    Colors.brown,
    Colors.orange,
    Colors.lightBlueAccent,
  ];
  StreamSubscription<String>? _generationSub;
  late ViewLogic viewLogic;
  late LocalDataSource localDataSource;
  late SharedPreferenceManager sharedPreferenceManager;
  late String _jsonInput;
  int? _nextChapter;
  int? _nextSubtopic;
  late PerformanceMonitor performanceMonitor;
  bool _isLoading = false;
  List<dynamic> data = [];
  // State variables to track quiz interaction
  int? _selectedAnswerIndex;
  bool _isSubmitted = false;
  bool _showingLoaderScreen = false;
  final PageController controller = PageController();
  @override
  void initState() {
    super.initState();
    student = di<StudentData>();
    subjectName = student.currentSubject ?? "SubjectName";
    studentName = student.name ?? "studentName";
    localDataSource = di<LocalDataSource>();
    viewLogic = di<ViewLogic>();
    _jsonInput = widget.jsonInput;
    _jsonInput = _jsonInput.trim();
    _nextChapter = widget.nextChapter;
    _nextSubtopic = widget.nextSubTopic;
    sharedPreferenceManager = di<SharedPreferenceManager>();
    performanceMonitor = di<PerformanceMonitor>();

    data = decodeJson(_jsonInput) ?? [];
    if (data.isNotEmpty) {
      data.add({"type": "Loading"});
    }
  }

  void reset() {
    setState(() {
      _selectedAnswerIndex = -1;
      _isSubmitted = false;
    });
  }

  List<dynamic>? decodeJson(String jsonInput) {
    // Map<String, dynamic> map = {};
    try {
      return jsonDecode(jsonInput);
      // print("mapp = $map");
      // map;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: FloatingActionButton.extended(
          tooltip: "AI Chat",
          backgroundColor: Colors.amber.shade900,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  gemmaService: widget.gemmaService,
                  performanceMonitor: performanceMonitor,
                ),
              ),
            );
          },
          label: const Text('AI Chat'),
          icon: const Icon(Icons.chat),
        ),
        body: PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemCount: data.length,
          itemBuilder: (context, index) {
            if ((!_isSubmitted) && index == data.length - 1) {
              continueLearning();
            }
            return Stack(
              children: [
                Container(
                  color: colors[Random().nextInt(6)],
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: showCard(index),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.grey,
                              size: 28,
                            ),
                      Text(
                        _isLoading ? 'Loading Next' : 'Swipe up for next',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget showCard(int index) {
    _showingLoaderScreen = false;
    Map<String, dynamic>? map = data[index];
    if (map != null) {
      if ((map.containsKey("type") && map["type"] == "learnings") &&
          map.containsKey("content")) {
        return learningCard(map["content"] ?? '');
      } else if (map.containsKey("type") && map["type"] == "quiz") {
        return quizCard(map);
      } else if (map.containsKey("type") && map["type"] == "Loading") {
        _showingLoaderScreen = true;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again'),
          ),
        );
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again')),
      );
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
  }

  Widget learningCard(String learning) {
    learning = learning.replaceAll(". ", ".\n\n");
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Key Learnings',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              learning,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget quizCard(Map<String, dynamic>? quiz) {
    String question = quiz?["question"] ?? '';
    String correctAnswer = quiz?["correctAnswer"].toString() ?? '';
    int correctAnswerIndex = int.parse(correctAnswer);
    List<dynamic> options = quiz?["options"] ?? [];
    return (quiz != null)
        ? Card(
            margin: EdgeInsets.only(top: 10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.quiz,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Quiz',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    question,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Generated Radio List Options
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      Color? tileColor;
                      if (_isSubmitted) {
                        if (index == correctAnswerIndex) {
                          tileColor = Colors
                              .green
                              .shade700; // Highlight correct answer green
                        } else if (_selectedAnswerIndex == index) {
                          tileColor = Colors
                              .red
                              .shade700; // Highlight user's wrong answer red
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: RadioListTile<int>(
                          title: Text(
                            options[index],
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          value: index,
                          groupValue: _selectedAnswerIndex,
                          onChanged: _isSubmitted
                              ? null // Disable interactions after submit
                              : (value) {
                                  setState(() {
                                    _selectedAnswerIndex = value;
                                  });
                                },
                        ),
                      );
                    },
                  ),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitted ? null : _submitQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_isSubmitted ? 'Submitted' : 'Submit Answer'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Feedback Message after Submission
                  if (_isSubmitted) ...[
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _selectedAnswerIndex == correctAnswerIndex
                              ? "🎉 Correct! Great job!"
                              : "❌ Incorrect. Try reviewing the learning card!",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _selectedAnswerIndex == correctAnswerIndex
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          )
        : SizedBox();
  }

  void _submitQuiz() {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option before submitting!'),
        ),
      );
      return;
    }
    setState(() {
      _isSubmitted = true;
    });

    continueLearning();
  }

  Future<void> continueLearning() async {
    if (_isLoading) return;
    _isLoading = true;
    int chapterNumber = _nextChapter ?? (di<SubjectData>().nextChapter ?? 0);
    int subTopicNumber = _nextSubtopic ?? (di<SubjectData>().nextSubtopic ?? 0);
    Subject? subject = di<SubjectData>().subject;
    String? text;
    String result = '';
    if (subject != null) {
      if ((subject.chapters.isNotEmpty &&
              subject.chapters.length > chapterNumber) &&
          (subject.chapters[chapterNumber].subtopics.isNotEmpty &&
              subject.chapters[chapterNumber].subtopics.length >
                  subTopicNumber)) {
        text = subject.chapters[chapterNumber].subtopics[subTopicNumber].text;
      }
    }
    if (text != null && text.isNotEmpty) {
      String? generatedText = await getFromCache(chapterNumber, subTopicNumber);
      if (generatedText != null) {
        updateNext(chapterNumber, subTopicNumber);
        var data1 = decodeJson(generatedText) ?? [];
        reset();
        if (_showingLoaderScreen) {
          controller.previousPage(
            duration: Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        } else {
          controller.nextPage(
            duration: Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        }
        data.removeLast();
        setState(() {
          data.addAll(data1);
          if (data.isNotEmpty) {
            data.add({"type": "Loading"});
          }
          _isLoading = false;
        });
      } else {
        String message =
            'Your total output must be concise and under 950 characters. Strictly No Profanity. You are a patient teacher. Use the given text and generate JSON containing learnings. Also generate another JSON containing 1 mcq with options and correct answer. Output structure [{type:learnings,content:learnings}, {type:quiz,question:question,options:[options],correctAnswer:correctAnswerIndex}]. Output only valid JSON. Do not include any text before JSON. Do not include any text after JSON. text - $text';
        if (mounted) {
          try {
            final stream = widget.gemmaService.sendMessage(
              message,
              context,
              fromChat: false,
            );
            _generationSub = stream.listen(
              (token) {
                result = result + token;
              },
              onDone: () {
                if (!mounted) return;
                result = viewLogic.cleanJson(result);
                cacheGenerated(result, chapterNumber, subTopicNumber);
                updateNext(chapterNumber, subTopicNumber);
                var data1 = decodeJson(result) ?? [];
                reset();
                if (_showingLoaderScreen) {
                  controller.previousPage(
                    duration: Duration(milliseconds: 100),
                    curve: Curves.linear,
                  );
                } else {
                  controller.nextPage(
                    duration: Duration(milliseconds: 100),
                    curve: Curves.linear,
                  );
                }
                data.removeLast();
                setState(() {
                  data.addAll(data1);
                  if (data.isNotEmpty) {
                    data.add({"type": "Loading"});
                  }
                  _isLoading = false;
                });
              },
              onError: (_) async {
                // Ensure the native side is stopped; the async* generator's finally
                // usually handles this, but errors surfacing via the subscriber
                // don't guarantee it, and a lingering `generating` state would
                // wedge the next sendMessage call.
                await widget.gemmaService.stopGeneration();
                setState(() {
                  _isLoading = false;
                });
              },
            );
          } catch (_) {
            await widget.gemmaService.stopGeneration();
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  void updateNext(int chapterNumber, int subTopicNumber) {
    final nextChapterAndSubtopic = viewLogic.calculateNextChapterAndSubtopic(
      chapterNumber,
      subTopicNumber,
    );
    chapterNumber = nextChapterAndSubtopic[0];
    subTopicNumber = nextChapterAndSubtopic[1];
    _nextChapter = null;
    _nextSubtopic = null;
    di<SubjectData>().setNextChapter(chapterNumber);
    di<SubjectData>().setNextSubtopic(subTopicNumber);
    sharedPreferenceManager.setInt(
      "${studentName}_${subjectName}_chapter",
      chapterNumber,
    );
    sharedPreferenceManager.setInt(
      "${studentName}_${subjectName}_chapter_subtopic",
      subTopicNumber,
    );
  }

  void cacheGenerated(String message, int chapterNumber, int subTopicNumber) {
    localDataSource.addDataToLocalHiveDB(
      "${studentName}_${subjectName}_${chapterNumber}_$subTopicNumber",
      SubjectGeneratedText(
        id: "${studentName}_${subjectName}_${chapterNumber}_$subTopicNumber",
        generatedText: message,
      ),
    );
  }

  Future<String?> getFromCache(int chapterNumber, int subTopicNumber) async {
    SubjectGeneratedText? subjectGeneratedText = await localDataSource
        .getDataFromLocalHiveDB<SubjectGeneratedText>(
          "${studentName}_${subjectName}_${chapterNumber}_$subTopicNumber",
        );
    return subjectGeneratedText?.generatedText;
  }

  @override
  void dispose() {
    controller.dispose();
    _generationSub?.cancel();
    super.dispose();
  }
}
