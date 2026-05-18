import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/student.dart';
import 'package:on_device_ai/screens/menu_button.dart';
import 'package:on_device_ai/screens/setup_screen.dart';
import 'package:on_device_ai/screens/subject_management_screen.dart';
import 'package:on_device_ai/screens/user_details_form.dart';
import 'package:on_device_ai/services/gemma_service.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:on_device_ai/utils/subject_data.dart';

class LearningHome extends StatefulWidget {
  final LocalDataSource localDataSource;
  final GemmaService gemmaService;
  const LearningHome({
    super.key,
    required this.localDataSource,
    required this.gemmaService,
  });

  @override
  State<LearningHome> createState() => _LearningHomeState();
}

class _LearningHomeState extends State<LearningHome> {
  bool _isLoading = true;
  bool _hasUserDetails = false;
  String _userName = '';
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  } // Check if profile exists inside local storage

  Future<void> _checkUserStatus() async {
    try {
      String? savedName;
      Student? student = await widget.localDataSource
          .getDataFromLocalHiveDB<Student>("student");
      if (student != null) {
        StudentData studentData = di<StudentData>();
        savedName = student.name;
        studentData.setName(savedName);
        studentData.setDisability(student.disability);
        studentData.setClassLevel(student.classLevel);
        studentData.setLanguage(student.language);
        studentData.addSubjects(student.subjects);
        studentData.setStudent(student);
      }

      setState(() {
        _hasUserDetails = savedName != null && savedName.isNotEmpty;
        if (_hasUserDetails) {
          _userName = savedName!;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  // Callback to refresh screen state after form completion
  void _onProfileCreated() {
    _checkUserStatus();
  }

  // Clear local data and reset state
  Future<void> _resetUserProfile() async {
    di<StudentData>().clear();
    di<SubjectData>().clear();
    await widget.localDataSource.clear();

    setState(() {
      _hasUserDetails = false;
      _userName = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details cleared successfully!')),
      );
    }
  }

  // Dialog to confirm deletion before resetting
  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Profile?'),
          content: const Text(
            'This will delete your name, settings, and learning preferences. You will need to set up your profile again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _resetUserProfile(); // Trigger data wipe
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Switch view to onboarding form if user profile data is missing
    if (!_hasUserDetails) {
      return UserDetailsForm(onSaveComplete: _onProfileCreated);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Hub'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // THE RESET PROFILE BUTTON
          Semantics(
            label: 'Reset user profile preferences and data',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Reset Profile',
              onPressed: _showResetConfirmationDialog,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome $_userName! Choose an option to begin:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),

            // Option A: Bite-size learning
            Semantics(
              label: 'Navigate to Bite size learning options',
              button: true,
              child: MenuButton(
                icon: Icons.auto_stories,
                label: 'Bite-size Learning',
                subtitle: 'Quick lessons and interactive quizzes',
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectManagementScreen(
                        localDataSource: widget.localDataSource,
                        gemmaService: widget.gemmaService,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Option B: AI Chat
            Semantics(
              label: 'Open AI Assistant Chatbot',
              button: true,
              child: MenuButton(
                icon: Icons.chat_bubble_outline,
                label: 'AI Chat',
                subtitle: 'Ask questions and get instant help',
                color: Theme.of(context).colorScheme.secondary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SetupScreen(gemmaService: widget.gemmaService),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
