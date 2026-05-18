import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:doc_text_extractor/doc_text_extractor.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/chapters.dart';
import 'package:on_device_ai/models/subtopics.dart';
import 'package:on_device_ai/utils/subject_data.dart';
import 'package:on_device_ai/models/subject.dart';

class AddSubjectFormModal extends StatefulWidget {
  final Function(String, Subject) onSubjectAdded;
  final LocalDataSource localDataSource;
  final String studentName;

  const AddSubjectFormModal({
    super.key,
    required this.onSubjectAdded,
    required this.localDataSource,
    required this.studentName,
  });

  @override
  State<AddSubjectFormModal> createState() => _AddSubjectFormModalState();
}

class _AddSubjectFormModalState extends State<AddSubjectFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  String? _pickedFileName;
  bool isExtracting = false;
  String error = '';
  Subject? subject;
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Uses file_picker plugin to choose reference document
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        var subject = await _extractText(result.paths.first);
        if (result.files.single.name.isNotEmpty && subject != null) {
          setState(() {
            _pickedFileName = result.files.single.name;
            this.subject = subject;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error. Please try again')));
      }
    }
  }

  void _submitForm() {
    if (subject != null) {
      if (_formKey.currentState!.validate()) {
        Navigator.pop(context); // Close the bottom modal
        widget.onSubjectAdded(_textController.text.trim(), subject!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject added successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Please try another file')),
        );
      }
    }
  }

  Future<Subject?> _extractText(String? path) async {
    String? extractText;
    Subject? subject;
    if (path != null && path.isNotEmpty) {
      final extractor = TextExtractor();
      try {
        final filePath = path;
        final chapters = await extractor.extractChapters(
          filePath,
          isUrl: false,
        );
        List<Chapters> chaptersList = [];
        if (chapters.isNotEmpty) {
          int selectChapter = (chapters.length > 1) ? 1 : 0;
          while (selectChapter < chapters.length) {
            String full = chapters[selectChapter].content;
            full = full.replaceAll(RegExp(r'\s{2,}'), ' ');

            // String halfText = full.split(RegExp(r'^\s*$')).first;
            // print('Text: ${halfText}');
            List<Subtopics> subtopics = [];
            if (full.length > 2000) {
              int textLength = 100;
              while (textLength < full.length) {
                int finalLength = ((textLength + 2000) > full.length)
                    ? full.length
                    : textLength + 2000;
                extractText = full.substring(textLength, finalLength - 1);
                subtopics.add(Subtopics(text: extractText));
                // widget.localDataSource.addDataToLocalHiveDB(typeId, dataObject)
                textLength = finalLength;
              }
            } else {
              extractText = full.substring(0, full.length - 1);
              subtopics.add(Subtopics(text: extractText));
            }
            if (subtopics.isNotEmpty) {
              extractText = subtopics[0].text;
            } else {
              extractText = null;
            }
            chaptersList.add(Chapters(subtopics: subtopics));
            selectChapter = selectChapter + 1;
          }
          if (chaptersList.isNotEmpty) {
            subject = Subject(
              name: _textController.text.trim(),
              chapters: chaptersList,
            );

            di<SubjectData>().setSubjectData(subject);
            cacheSubject(subject);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        }
        setState(() {
          error = e.toString();
        });
      }
    }
    setState(() {
      isExtracting = false;
    });
    return subject;
  }

  void cacheSubject(Subject subject) {
    try {
      widget.localDataSource.addDataToLocalHiveDB(
        "${widget.studentName}_${subject.name}",
        subject,
      );
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensures modal reacts gracefully to the virtual soft keyboard opening up
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.0, 24.0, 20.0, bottomInset + 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap layout snugly around contents
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Configure New Subject',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Form Input Field
            Semantics(
              label: 'Text field input for subject headline titles',
              child: TextFormField(
                controller: _textController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g., Geography or History',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a valid subject title name';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),

            // Accessible File Picker Interaction Block
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                (_pickedFileName == null || subject == null)
                    ? 'Attach Learning Material'
                    : 'Change File',
              ),
            ),

            // File status readout block
            if (_pickedFileName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Selected: $_pickedFileName',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.blue, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Processing',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),

            // Dynamic Action Tray
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitForm,
                  child: const Text('Create Subject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
