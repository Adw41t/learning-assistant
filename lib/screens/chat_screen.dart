import 'dart:async';
import 'dart:io' hide BytesBuilder;
// import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_device_ai/injection_container.dart';
import 'package:on_device_ai/utils/student_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/gemma_service.dart';
import '../services/performance_monitor.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

// Design token constants — will be replaced by ThemeData integration later.
const _kBgColor = Color(0xFF000000);
const _kSurfaceColor = Color(0xFF181818);
const _kElevatedColor = Color(0xFF1E1E1E);
const _kAccentColor = Color(0xFF47A1E6);
const _kErrorColor = Color(0xFFCD5454);
const _kPerfBarColor = Color(0xFF0C0C0C);
const _kDisabledColor = Color(0xFF333333);

/// Main chat interface for interacting with Gemma 4 E2B on-device.
///
/// Features:
/// - Streaming token-by-token responses
/// - Performance status bar (thermal state, tokens/sec)
/// - Stop generation button
/// - Clear chat
class ChatScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const ChatScreen({
    super.key,
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  StreamSubscription<String>? _generationSub;
  Uint8List? audioBytes;
  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _generationSub?.cancel();
    super.dispose();
  }

  /// Threshold (in logical pixels) within which we still consider the user
  /// to be "at the bottom" of the scroll view. Lets us respect manual
  /// scroll-back without stealing the viewport on every token.
  static const double _autoScrollThreshold = 64.0;

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels <= _autoScrollThreshold;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _failGeneration(int aiMessageIndex) {
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      if (aiMessageIndex < _messages.length) {
        _messages[aiMessageIndex] = const _ChatMessage(
          text: 'Something went wrong. Please try again.',
          isUser: false,
        );
      }
    });
    widget.performanceMonitor.endSession();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if ((text.isEmpty && audioBytes == null) || _isGenerating) return;

    // Check throttle before mutating state so the typed message is preserved.
    if (widget.performanceMonitor.shouldReduceLoad) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.performanceMonitor.statusDescription),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kSurfaceColor,
          ),
        );
      }
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();

    // Add user message + empty AI placeholder for streaming.
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(const _ChatMessage(text: '', isUser: false));
      _isGenerating = true;
    });
    final aiMessageIndex = _messages.length - 1;
    _scrollToBottom();

    widget.performanceMonitor.startSession();

    try {
      final stream = widget.gemmaService.sendMessage(
        text,
        context,
        fromChat: true,
        audio: audioBytes,
      );
      _generationSub = stream.listen(
        (token) {
          if (!mounted) return;
          // Capture scroll state *before* the new token grows maxScrollExtent
          // so an auto-scroll only fires if the user was already at the bottom.
          final shouldStick = _isNearBottom();
          setState(() {
            if (aiMessageIndex < _messages.length) {
              _messages[aiMessageIndex] = _ChatMessage(
                text: _messages[aiMessageIndex].text + token,
                isUser: false,
              );
            }
          });
          if (shouldStick) _scrollToBottom();
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
          widget.performanceMonitor.endSession();
        },
        onError: (_) async {
          // Ensure the native side is stopped; the async* generator's finally
          // usually handles this, but errors surfacing via the subscriber
          // don't guarantee it, and a lingering `generating` state would
          // wedge the next sendMessage call.
          await widget.gemmaService.stopGeneration();
          _failGeneration(aiMessageIndex);
        },
      );
    } catch (_) {
      await widget.gemmaService.stopGeneration();
      _failGeneration(aiMessageIndex);
    }
  }

  Future<void> _stopGeneration() async {
    final sub = _generationSub;
    _generationSub = null;
    await sub?.cancel();
    await widget.gemmaService.stopGeneration();
    widget.performanceMonitor.endSession();
    if (!mounted) return;
    setState(() => _isGenerating = false);
  }

  Future<void> _clearChat() async {
    // Fully tear down any in-flight generation BEFORE clearing history.
    // InferenceChat.clearHistory() closes and re-creates the native session,
    // which would race with an active generateChatResponseAsync loop.
    final sub = _generationSub;
    _generationSub = null;
    await sub?.cancel();
    if (_isGenerating) {
      await widget.gemmaService.stopGeneration();
      widget.performanceMonitor.endSession();
    }
    await widget.gemmaService.clearChat();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _kBgColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // _PerformanceBar(
            //   gemmaService: widget.gemmaService,
            //   performanceMonitor: widget.performanceMonitor,
            // ),
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount:
                          _messages.length +
                          (_isGenerating && _messages.last.text.isEmpty
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const TypingIndicator();
                        }
                        final msg = _messages[index];
                        return ChatBubble(
                          text: msg.text,
                          isUser: msg.isUser,
                          isStreaming:
                              _isGenerating &&
                              index == _messages.length - 1 &&
                              !msg.isUser,
                        );
                      },
                    ),
            ),

            // Floating input bar — rebuilds when throttle state changes so
            // the send button accurately reflects whether a send will succeed.
            ListenableBuilder(
              listenable: widget.performanceMonitor,
              builder: (context, _) => _InputBar(
                controller: _textController,
                focusNode: _focusNode,
                isGenerating: _isGenerating,
                isThrottled: widget.performanceMonitor.shouldReduceLoad,
                onSend: _sendMessage,
                onStop: _stopGeneration,
                addAudio: (Uint8List audio) {
                  audioBytes = audio;
                  _sendMessage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _kBgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'AI Chat',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Semantics(
          label: 'Clear chat',
          child: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: _messages.isEmpty
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white70,
            ),
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Performance bar
// ---------------------------------------------------------------------------

class _PerformanceBar extends StatelessWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const _PerformanceBar({
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gemmaService, performanceMonitor]),
      builder: (context, _) {
        final isGenerating = gemmaService.isGenerating;
        final tps = gemmaService.tokensPerSecond;
        final throttled = performanceMonitor.isThrottled;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: _kPerfBarColor,
          child: Row(
            children: [
              // Offline pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _kAccentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: _kAccentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Backend info
              Text(
                gemmaService.backendInfo,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),

              const Spacer(),

              // Tokens/sec — only during active generation
              if (isGenerating && tps > 0) ...[
                Text(
                  '${tps.toStringAsFixed(1)} tok/s',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 8),
              ],

              // Cooldown indicator (session-time cap hit).
              if (throttled) ...[
                const Icon(
                  Icons.pause_circle_outline,
                  size: 13,
                  color: _kErrorColor,
                ),
                const SizedBox(width: 3),
                const Text(
                  'COOLDOWN',
                  style: TextStyle(
                    color: _kErrorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kSurfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              size: 36,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome ${di<StudentData>().name}! Ask me anything',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Running Gemma 4 E2B locally on your device',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool isThrottled;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final Function(Uint8List) addAudio;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isThrottled,
    required this.onSend,
    required this.onStop,
    required this.addAudio,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late final AudioRecorder _audioRecorder;
  bool _isWriting = false;
  bool _isRecording = false;
  String? _localRecordingPath;
  // StreamSubscription<List<int>>? _streamSubscription;
  // final BytesBuilder _audioBytesBuilder = BytesBuilder(copy: false);
  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder(); // Initialize the engine
  }

  @override
  void dispose() {
    _audioRecorder.dispose(); // Always release audio pipeline resources
    super.dispose();
  }

  Future<void> _startVoiceRecord() async {
    try {
      // 1. Check and request hardware permissions
      if (await _audioRecorder.hasPermission()) {
        // _audioBytesBuilder.clear();

        // 2. Get local device system temp directory path
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';

        // 3. Trigger haptic buzz indicating recording has initialized
        await HapticFeedback.vibrate();

        // 4. Fire up the physical microphone
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav, // Enforces the WAV container/headers
            sampleRate: 16000, // MUST be exactly 16kHz for Gemma 4
            numChannels: 1, // MUST be mono
          ),
          path: path,
        );
        //future streaming
        /*
        // Start streaming directly to memory instead of writing to a path string
        final audioStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
          ), // Raw linear PCM audio bytes
        );
        // Listen to incoming binary chunks in real-time
        _streamSubscription = audioStream.listen((List<int> chunk) {
          _audioBytesBuilder.add(chunk);
        });
*/
        setState(() {
          _isRecording = true;
          _localRecordingPath = path;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _stopVoiceRecord() async {
    if (!_isRecording) return;
    //future streaming
    /*    try {
      await _audioRecorder.stop();
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      final Uint8List completeAudioBytes = _audioBytesBuilder.takeBytes();
      widget.addAudio(completeAudioBytes);
    } catch (e) {
      print("Error stopping stream recording: $e");
      return null;
    }
    */

    try {
      // Stops recording engine and flushes track to disk file
      final finalPath = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (finalPath != null) {
        File recordedFile = File(finalPath);
        if (await recordedFile.exists()) {
          Uint8List audioBytes = await recordedFile.readAsBytes();
          widget.addAudio(audioBytes);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error stopping microphone recording: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final canSend = !widget.isGenerating && !widget.isThrottled;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPadding),
      color: _kSurfaceColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kElevatedColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: const Text(
                        "Recording Audio...",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      // Guard hardware-keyboard Enter from firing during generation
                      // or throttle — the _sendMessage guard would silently drop
                      // the user's typed text.
                      onSubmitted: (_) {
                        if (canSend) widget.onSend();
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      cursorColor: _kAccentColor,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(
                          color: Colors.white30,
                          fontSize: 15,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: _kAccentColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Stop button replaces send during generation
          if (widget.isGenerating)
            Semantics(
              label: "Double tap to stop AI message",
              child: _ActionButton(
                onPressed: widget.onStop,
                backgroundColor: _kErrorColor,
                child: const Icon(
                  Icons.stop_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            )
          else
            // _isWriting
            //     ?
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final hasText = widget.controller.text.trim().isNotEmpty;
                if (hasText != _isWriting) {
                  _isWriting = hasText;
                }
                final enabled = hasText && !widget.isThrottled;
                return Semantics(
                  label: enabled
                      ? "Double tap to send message"
                      : "Currently disabled",
                  child: _ActionButton(
                    onPressed: enabled ? widget.onSend : null,
                    backgroundColor: enabled ? _kAccentColor : _kDisabledColor,
                    child: Icon(
                      Icons.send,
                      color: enabled ? Colors.white : Colors.white30,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
          /*  : Semantics(
                    label: "Double tap to audio message",
                    child: GestureDetector(
                      // Replicates native hardware event loop triggers
                      onLongPressStart: (_) async => await _startVoiceRecord(),
                      onLongPressEnd: (_) async => await _stopVoiceRecord(),
                      child: _buildButtonIcon(
                        _isRecording ? Icons.mic_none : Icons.mic,
                        color: _isRecording
                            ? Colors.red
                            : const Color(0xFF00A884),
                      ),
                    ),
                  ), */
        ],
      ),
    );
  }

  Widget _buildButtonIcon(
    IconData icon, {
    Color color = const Color(0xFF00A884),
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 24.0),
    );
  }
}

/// Reusable circular action button for the input bar.
class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Widget child;

  const _ActionButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
