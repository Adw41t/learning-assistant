import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/models/subject_generated_text.dart';
import 'package:on_device_ai/screens/chat_screen.dart';
import 'package:on_device_ai/screens/tiktok_scroll_screen.dart';
import 'package:on_device_ai/services/performance_monitor.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:on_device_ai/viewlogic/view_logic.dart';

import '../services/gemma_service.dart';

// Hardcoded design tokens — theme integration deferred.
const _kBgColor = Color(0xFF000000);
const _kCardColor = Color(0xFF181818);
const _kAccent = Color(0xFF47A1E6);
const _kSuccess = Color(0xFF5BC682);
const _kError = Color(0xFFCD5454);
const _kTextPrimary = Color(0xFFFFFFFF);
const _kTextMuted = Color(0x80FFFFFF); // rgba(255,255,255,0.5)

/// Onboarding screen that handles model download and initialization.
///
/// Shows download progress for the 2.58 GB Gemma 4 E2B model on first launch.
/// On subsequent launches, skips straight to model loading (GPU warm-up).
class SetupScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final String? message;
  final int? currentChapter;
  final int? currentSubTopic;
  final bool summarise;

  const SetupScreen({
    super.key,
    required this.gemmaService,
    this.message,
    this.currentChapter,
    this.currentSubTopic,
    this.summarise = false,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  String _statusMessage = 'Checking model...';
  bool _hasError = false;
  bool _isGenerating = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late LocalDataSource localDataSource;
  late ViewLogic viewLogic;

  late StudentData student;
  String? studentName;
  String? subjectName;
  @override
  void initState() {
    super.initState();
    localDataSource = di<LocalDataSource>();
    viewLogic = di<ViewLogic>();
    student = di<StudentData>();
    subjectName = student.currentSubject ?? "SubjectName";
    studentName = student.name ?? "studentName";

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSetup();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startSetup() async {
    widget.gemmaService.setStudentData(student);
    widget.gemmaService.setLocalDataSource(localDataSource);
    try {
      // Step 0: Framework init (idempotent). Done here so failures surface
      // through this retry flow rather than crashing at app launch.
      await widget.gemmaService.initFramework();

      // Step 1: Check if model is already installed
      final installed = await widget.gemmaService.isModelInstalled();

      if (!installed) {
        // Step 2a: Download model (first launch)
        if (!mounted) return;
        setState(() => _statusMessage = 'This is a one-time setup.');
        await widget.gemmaService.downloadModel();
      }

      // Step 3: Load model into GPU memory
      if (!mounted) return;
      setState(() => _statusMessage = 'Loading model to GPU...');
      await widget.gemmaService.loadModel();

      // Done
      if (widget.summarise &&
          (widget.message != null && widget.message!.isNotEmpty)) {
        summarizeText(widget.message!);
      } else {
        if (mounted) {
          unawaited(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  gemmaService: widget.gemmaService,
                  performanceMonitor: PerformanceMonitor(),
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'Setup failed: $e';
      });
    }
  }

  Future<void> summarizeText(String text) async {
    String result = '';
    String? generatedText = await getFromCache(
      widget.currentChapter ?? 0,
      widget.currentSubTopic ?? 0,
    );
    if (generatedText != null) {
      navigateToScrollScreen(generatedText);
    } else {
      if (mounted) {
        setState(() => _statusMessage = 'Processing ...');
        final stream = widget.gemmaService.sendMessage(
          text,
          context,
          fromChat: false,
        );
        stream.listen(
          (token) {
            if (!mounted) return;
            setState(() {
              _isGenerating = false;
            });
            result = result + token;
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _isGenerating = true;
            });
            result = viewLogic.cleanJson(result);
            // result = jsonEncode(result);
            cacheGenerated(
              result,
              widget.currentChapter ?? 0,
              widget.currentSubTopic ?? 0,
            );
            navigateToScrollScreen(result);
          },
          onError: (_) async {
            // Ensure the native side is stopped; the async* generator's finally
            // usually handles this, but errors surfacing via the subscriber
            // don't guarantee it, and a lingering `generating` state would
            // wedge the next sendMessage call.
            await widget.gemmaService.stopGeneration();
            setState(() {
              _isGenerating = false;
            });
          },
        );
      }
    }
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

  void navigateToScrollScreen(String result) {
    final nextChapterAndSubtopic = viewLogic.calculateNextChapterAndSubtopic(
      widget.currentChapter ?? 0,
      widget.currentSubTopic ?? 0,
    );
    final int chapterNumber = nextChapterAndSubtopic[0];
    final int subTopicNumber = nextChapterAndSubtopic[1];

    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TikTokScrollScreen(
            jsonInput: result,
            gemmaService: widget.gemmaService,
            nextChapter: chapterNumber,
            nextSubTopic: subTopicNumber,
          ),
        ),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _statusMessage = 'Retrying...';
    });
    await _startSetup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _AppIconArea(pulseAnimation: _pulseAnimation),
              const SizedBox(height: 28),
              _AppTitleBlock(),
              const Spacer(flex: 2),
              ListenableBuilder(
                listenable: widget.gemmaService,
                builder: (context, _) {
                  return _ProgressSection(
                    state: widget.gemmaService.state,
                    progress: widget.gemmaService.downloadProgress,
                    statusMessage: _statusMessage,
                    hasError: _hasError,
                    isGenerating: _isGenerating,
                  );
                },
              ),
              if (_hasError) ...[
                const SizedBox(height: 24),
                _RetryButton(onRetry: _retry),
              ],
              const Spacer(flex: 1),
              // Don't advertise "100% offline" while actively downloading —
              // the user is demonstrably online at that moment.
              ListenableBuilder(
                listenable: widget.gemmaService,
                builder: (context, _) {
                  if (widget.gemmaService.state ==
                      GemmaServiceState.downloading) {
                    return const SizedBox.shrink();
                  }
                  return const _OfflineInfoCard();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _AppIconArea extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _AppIconArea({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _kAccent.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.assistant, size: 52, color: _kAccent),
      ),
    );
  }
}

class _AppTitleBlock extends StatelessWidget {
  const _AppTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Setting up AI model',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Powered by Gemma 4 E2B',
          style: TextStyle(
            color: _kTextMuted,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final GemmaServiceState state;
  final double progress;
  final String statusMessage;
  final bool hasError;
  final bool isGenerating;

  const _ProgressSection({
    required this.state,
    required this.progress,
    required this.statusMessage,
    required this.hasError,
    required this.isGenerating,
  });

  bool get _showDownloadCard => state == GemmaServiceState.downloading;

  bool get _showSpinner {
    if (hasError) return false;
    // Explicitly list the "working, no progress bar yet" states so future
    // enum additions don't silently start showing a spinner.
    return state == GemmaServiceState.uninitialized ||
        state == GemmaServiceState.downloaded ||
        state == GemmaServiceState.loading ||
        state == GemmaServiceState.generating;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showDownloadCard) ...[
          _DownloadProgressCard(progress: progress),
          const SizedBox(height: 20),
        ] else if (_showSpinner) ...[
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasError ? _kError : _kTextMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgressCard extends StatelessWidget {
  final double progress;

  const _DownloadProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final downloadedGb = clampedProgress * 2.58;
    final percentText = '${(clampedProgress * 100).toStringAsFixed(1)}%';
    final sizeText = '${downloadedGb.toStringAsFixed(2)} / 2.58 GB';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DOWNLOADING MODEL',
                style: TextStyle(
                  color: _kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                percentText,
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Custom progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: clampedProgress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sizeText,
            style: const TextStyle(color: _kTextMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          backgroundColor: _kError,
          foregroundColor: _kTextPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: const Text(
          'RETRY SETUP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _OfflineInfoCard extends StatelessWidget {
  const _OfflineInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: _kSuccess,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '100% offline after setup\nNo internet connection required.',
              style: TextStyle(color: _kTextMuted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
