import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/student.dart';
import 'package:on_device_ai/utils/student_data.dart';

class UserDetailsForm extends StatefulWidget {
  final VoidCallback onSaveComplete;

  const UserDetailsForm({super.key, required this.onSaveComplete});

  @override
  State<UserDetailsForm> createState() => _UserDetailsFormState();
}

class _UserDetailsFormState extends State<UserDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _languageController = TextEditingController();

  String? _selectedClass;
  String? _selectedDisability;

  // Options configuration blocks
  final List<String> _classList = [
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
  ];
  final List<String> _disabilityList = [
    'None',
    'Visual Impairment',
    'Dyslexia',
    'Other',
  ];

  LocalDataSource? localDataSource;
  @override
  void initState() {
    super.initState();
    localDataSource = di<LocalDataSource>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text.trim();
      String classLevel = _selectedClass ?? 'Unspecified';
      String langauge = _languageController.text.trim();
      String disability = _selectedDisability ?? 'None';
      var student = Student(
        name: name,
        classLevel: classLevel,
        language: langauge,
        disability: disability,
        subjects: [],
      );

      if (localDataSource != null) {
        localDataSource!.addDataToLocalHiveDB("student", student);
      }

      var studentData = di<StudentData>();
      studentData.setName(name);
      studentData.setClassLevel(classLevel);
      studentData.setLanguage(langauge);
      studentData.setDisability(disability);
      studentData.setStudent(student);

      widget.onSaveComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Help us personalize your learning platform experience.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 1. Full Name Text Entry
              Semantics(
                label: 'Input field for your name',
                child: TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 2. Class Selector Dropdown
              DropdownButtonFormField<String>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  labelText: 'Class / Class Level',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                ),
                items: _classList.map((String item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) => setState(() => _selectedClass = value),
                validator: (value) =>
                    value == null ? 'Please select your class' : null,
              ),
              const SizedBox(height: 20),

              // 3. Language Selection
              Semantics(
                label: 'Input field for your Preferred Language',
                child: TextFormField(
                  controller: _languageController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Language',
                    hintText: 'English',
                    prefixIcon: Icon(Icons.language),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your Preferred Language.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 4. Learning Accommodation Selection
              DropdownButtonFormField<String>(
                value: _selectedDisability,
                decoration: const InputDecoration(
                  labelText: 'Learning Support / Accommodations',
                  prefixIcon: Icon(Icons.accessibility_new),
                  border: OutlineInputBorder(),
                ),
                items: _disabilityList.map((String item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedDisability = value),
                validator: (value) =>
                    value == null ? 'Please select an option' : null,
              ),
              const SizedBox(height: 36),

              // Submit Action configuration
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _saveProfile,
                child: const Text(
                  'Save Profile & Continue',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
