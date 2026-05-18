import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:on_device_ai/hive/local_datasource.dart';
import 'package:on_device_ai/models/performance.dart';
import 'package:on_device_ai/utils/student_data.dart';

/// Manages Gemma model lifecycle: download, initialization, inference.
///
/// Platform-aware model selection:
/// - Android: Gemma 4 E2B (.litertlm, 2.4 GB) via LiteRT-LM
/// - iOS: Gemma 3 1B IT (.task, 0.5 GB) via MediaPipe
///   (.litertlm crashes on iOS — Metal GPU delegate not supported yet)
class GemmaService extends ChangeNotifier {
  // Gemma 4 E2B via LiteRT-LM — public, no HuggingFace auth needed.
  // Android only. iOS support pending Google's LiteRT-LM Swift API.

  static const int _maxTokens = 4096;
  static const int _maxGenerationTokens = 2048;

  InferenceModel? _model;
  EmbeddingModel? embeddingModel;
  InferenceChat? _chat;

  GemmaServiceState _state = GemmaServiceState.uninitialized;
  double _downloadProgress = 0.0;
  String? _error;
  bool _frameworkInitialized = false;

  // Performance tracking
  int _tokensGenerated = 0;
  final Stopwatch _generationStopwatch = Stopwatch();

  GemmaServiceState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;
  bool get isReady => _state == GemmaServiceState.ready;
  bool get isGenerating => _state == GemmaServiceState.generating;
  int get tokensGenerated => _tokensGenerated;

  final List<Tool> _tools = [
    const Tool(
      name: 'get_student_performance_from_database',
      description: "Get Student Performance data from database",
      parameters: {
        'type': 'object',
        'properties': {
          'studentName': {'type': 'string', 'description': 'student Name'},
          'subject': {'type': 'string', 'description': 'subject'},
          'topic': {'type': 'string', 'description': 'topic'},
        },
        'required': ['studentName', 'subject', 'topic'],
      },
    ),
    const Tool(
      name: 'save_student_performance_to_database',
      description: 'Save Student Performance to database',
      parameters: {
        'type': 'object',
        'properties': {
          'score': {'type': 'string', 'description': 'Score'},
          'studentName': {'type': 'string', 'description': 'student Name'},
          'subject': {'type': 'string', 'description': 'subject'},
          'topic': {'type': 'string', 'description': 'topic'},
          'timeTaken': {'type': 'string', 'description': 'time Taken'},
          'mistakesMade': {'type': 'string', 'description': 'mistakes Made'},
          'summaryFeedback': {
            'type': 'string',
            'description': 'summary Feedback',
          },
        },
        'required': [
          'score',
          'studentName',
          'subject',
          'topic',
          'timeTaken',
          'mistakesMade',
          'summaryFeedback',
        ],
      },
    ),
  ];
  late LocalDataSource localDataSource;
  StudentData? studentData;
  void setLocalDataSource(LocalDataSource localDataSource) {
    this.localDataSource = localDataSource;
  }

  void setStudentData(StudentData studentData) {
    this.studentData = studentData;
  }

  /// Initialize the FlutterGemma framework. Idempotent — safe to call from
  /// the setup flow so a failure surfaces through the normal retry path.
  Future<void> initFramework({String? huggingFaceToken}) async {
    if (_frameworkInitialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: huggingFaceToken,
      maxDownloadRetries: 10,
    );
    _frameworkInitialized = true;
  }

  /// Check if the model is already installed locally.
  Future<bool> isModelInstalled() async {
    return FlutterGemma.hasActiveModel();
  }

  /// Download and install the Gemma 4 E2B model from HuggingFace.
  Future<void> downloadModel() async {
    if (_state == GemmaServiceState.downloading ||
        _state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      throw StateError('Cannot start download while ${_state.name}.');
    }
    _state = GemmaServiceState.downloading;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Flutter assets
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromBundled('gemma4e2b.litertlm').install();
      _state = GemmaServiceState.downloaded;
      notifyListeners();
      // downloadEmbeddingModel();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Download failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  //Future for RAG
  /// Download and install the embedding model from HuggingFace.
  // Future<void> downloadEmbeddingModel() async {
  //   if (_state == GemmaServiceState.downloading ||
  //       _state == GemmaServiceState.loading ||
  //       _state == GemmaServiceState.generating) {
  //     throw StateError('Cannot start download while ${_state.name}.');
  //   }
  //   _state = GemmaServiceState.downloading;
  //   _downloadProgress = 0.0;
  //   _error = null;
  //   notifyListeners();

  //   try {
  //     // Flutter assets
  //     await FlutterGemma.installEmbedder()
  //         .modelFromBundled('gecko1024.tflite')
  //         .tokenizerFromBundled('sentencepiece.model')
  //         .install();
  //     _state = GemmaServiceState.embedderDownloaded;
  //     notifyListeners();
  //   } catch (e) {
  //     _state = GemmaServiceState.error;
  //     _error = 'Download failed: $e';
  //     notifyListeners();
  //     rethrow;
  //   }
  // }

  /// Load the model into memory and create a chat session.
  /// Call during splash screen for background warm-up.
  Future<void> loadModel() async {
    if (_state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      throw StateError('Cannot load while ${_state.name}.');
    }
    _state = GemmaServiceState.loading;
    _error = null;
    notifyListeners();

    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );

      _chat = await _model!.createChat(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        tokenBuffer: 2048,
        modelType: ModelType.gemmaIt,
        supportImage: true,
        supportAudio: true,
        tools: _tools, // Pass your tools
        supportsFunctionCalls:
            true, // Enable function calling (required for tools)
        toolChoice: ToolChoice.auto, // auto (default) | required | none
      );

      _state = GemmaServiceState.ready;
      notifyListeners();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Model loading failed: $e';
      notifyListeners();
      rethrow;
    }
    // Future
    /*
    try {
      // Create embedding model instance
      embeddingModel = await FlutterGemma.getActiveEmbedder();
    } catch (e) {
      print(e);
      _state = GemmaServiceState.error;
      _error = 'Model loading failed: $e';
      notifyListeners();
      rethrow;
    }
    */
  }

  /// Send a message and stream back the response token by token.
  ///
  /// Enforces [_maxGenerationTokens] limit to prevent thermal throttling.
  /// Returns a stream of text tokens.
  Stream<String> sendMessage(
    String text,
    BuildContext context, {
    bool fromChat = false,
    Uint8List? audio,
  }) async* {
    // Future
    // String? context;
    /*
    if (embeddingModel != null) {
      // Step 1: Initialize VectorStore
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/my_vector_store.db';
      print('initializeVectorStore');
      await FlutterGemmaPlugin.instance.initializeVectorStore(dbPath);

      // Step 2: Add documents with embeddings
      final documents = [
        'Flutter is a UI toolkit for building apps',
        'Dart is the programming language used with Flutter',
        'Machine learning enables AI capabilities',
      ];

      for (final doc in documents) {
        // Generate document embedding (uses document prefix for better retrieval)
        final embedding = await embeddingModel!.generateEmbedding(
          doc,
          taskType: TaskType.retrievalDocument,
        );

        print('generateEmbedding');
        // Add to vector store
        await FlutterGemmaPlugin.instance.addDocumentWithEmbedding(
          id: 'doc_${documents.indexOf(doc)}',
          content: doc,
          embedding: embedding,
          // metadata: {'source': 'example', 'index': documents.indexOf(doc)},
        );
      }
      print('addDocumentWithEmbedding');
      // Step 3: Search for similar documents
      final query = 'What is Flutter?';
      final queryEmbedding = await embeddingModel!.generateEmbedding(query);

      final results = await FlutterGemmaPlugin.instance.searchSimilar(
        query: query,
        topK: 3, // Return top 3 results
        threshold: 0.7, // Minimum similarity score (0.0-1.0)
      );

      print('searchSimilar');
      // Step 4: Use results
      for (final result in results) {
        print('Score: ${result.similarity}');
        print('Content: ${result.content}');
        print('Metadata: ${result.metadata}');
      }

      // Step 5: RAG with inference model
      context = results.map((r) => r.content).join('\n');
    }

    */
    String prePrompt = '';
    if (fromChat) {
      prePrompt =
          "Your total output must be concise and under 950 characters. Strictly No Profanity. Do not output gibberish symbols. You are a patient teacher. You may give simple real-life examples. During quiz or test, give hints, do not reveal answer directly. Adapt as per student.";
    }
    if (studentData != null) {
      final studentInfo =
          "Student name = ${studentData?.name}, preferred language = ${studentData?.language}, class/grade = ${studentData?.classLevel} disability = ${studentData?.disability}";
      prePrompt = prePrompt + studentInfo;
    }
    final prompt = '$prePrompt\nQuestion: $text';

    if (_chat == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
    if (_state == GemmaServiceState.generating) {
      throw StateError('Already generating. Stop current generation first.');
    }

    _state = GemmaServiceState.generating;
    _tokensGenerated = 0;
    _error = null;
    _generationStopwatch.reset();
    _generationStopwatch.start();
    notifyListeners();

    try {
      Message? message;
      if (audio != null) {
        message = Message.withAudio(
          text: "$text. Transcribe this audio segment into English text.",
          audioBytes: audio,
          isUser: true,
        );
      } else {
        message = Message.text(text: prompt, isUser: true);
      }
      await _chat!.addQuery(message);

      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          _tokensGenerated++;

          // Enforce generation token limit to prevent thermal throttling
          if (_tokensGenerated >= _maxGenerationTokens) {
            await _chat!.stopGeneration();
            yield response.token;
            break;
          }

          yield response.token;
        } else if (response is FunctionCallResponse) {
          if (context.mounted) {
            _handleFunctionCall(response, context);
          }
        } else if (response is ParallelFunctionCallResponse) {
          for (final call in response.calls) {
            if (context.mounted) {
              await _handleFunctionCall(call, context);
            }
          }
        }
        // ThinkingResponse and FunctionCallResponse are ignored for basic chat
      }
    } catch (e) {
      _error = 'Generation failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      _generationStopwatch.stop();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  Future<void> _handleFunctionCall(
    FunctionCallResponse functionCall,
    BuildContext con,
  ) async {
    // Execute the requested function
    Map<String, dynamic> toolResponse;

    switch (functionCall.name) {
      case 'get_student_performance_from_database':
        // final score = functionCall.args['score'] as String?;
        final studentName = functionCall.args['studentName'] as String?;
        final subject = functionCall.args['subject'] as String?;
        final topic = functionCall.args['topic'] as String?;
        // final timeTaken = functionCall.args['timeTaken'] as String?;
        // final mistakesMade = functionCall.args['mistakesMade'] as String?;
        // final summaryFeedback = functionCall.args['summaryFeedback'] as String?;
        // Your implementation here
        final performance = await localDataSource
            .getDataFromLocalHiveDB<Performance>(
              "${studentName ?? 'studentName'}_${subject ?? 'subject'}_${topic ?? "topic"}",
            );
        final timeTaken = performance?.timeTaken;
        final mistakesMade = performance?.mistakesMade;
        final summaryFeedback = performance?.summaryFeedback;
        final score = performance?.score;

        toolResponse = {
          'status': 'success',
          'message':
              'Student performance data. Score : $score, studentName: $studentName, subject:$subject, topic:$topic, timeTaken:$timeTaken, mistakesMade:$mistakesMade, summaryFeedback:$summaryFeedback',
        };
        break;
      case 'save_student_performance_to_database':
        final score = functionCall.args['score'] as String?;
        final studentName = functionCall.args['studentName'] as String?;
        final subject = functionCall.args['subject'] as String?;
        final topic = functionCall.args['topic'] as String?;
        final timeTaken = functionCall.args['timeTaken'] as String?;
        final mistakesMade = functionCall.args['mistakesMade'] as String?;
        final summaryFeedback = functionCall.args['summaryFeedback'] as String?;
        final id =
            "${studentName ?? 'studentName'}_${subject ?? 'subject'}_${topic ?? "topic"}";
        final performance = Performance(
          id: id,
          score: score ?? "",
          studentName: studentName ?? "",
          subject: subject ?? "",
          topic: topic ?? "",
          timeTaken: timeTaken ?? "",
          mistakesMade: mistakesMade ?? "",
          summaryFeedback: summaryFeedback ?? "",
        );
        // Show alert dialog
        localDataSource.addDataToLocalHiveDB(id, performance);
        toolResponse = {'status': 'success', 'message': 'Saved'};
        break;

      default:
        toolResponse = {'error': 'Unknown function: ${functionCall.name}'};
    }

    // Send the tool response back to the model
    final toolMessage = Message.toolResponse(
      toolName: functionCall.name,
      response: toolResponse,
    );
    await _chat?.addQueryChunk(toolMessage);

    // The model will then generate a final response explaining what it did
    // final finalResponse = await _chat?.generateChatResponse();
    // if (finalResponse is TextResponse) {
    //   print('Model: ${finalResponse.token}');
    // }
  }

  /// Stop any in-progress generation.
  Future<void> stopGeneration() async {
    if (_chat != null && _state == GemmaServiceState.generating) {
      await _chat!.stopGeneration();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  /// Clear chat history and start fresh.
  ///
  /// Caller is responsible for stopping any in-flight generation first —
  /// [InferenceChat.clearHistory] closes and re-creates the native session
  /// and will race with an active [generateChatResponseAsync] loop.
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
      _tokensGenerated = 0;
      _generationStopwatch.reset();
      notifyListeners();
    }
  }

  /// Get the model description. Backend is negotiated by flutter_gemma at
  /// load time — we don't assert GPU here because a CPU fallback is possible.
  String get backendInfo => 'Gemma 4 E2B';

  /// Tokens per second from the last generation.
  double get tokensPerSecond {
    if (_generationStopwatch.elapsedMilliseconds == 0) return 0;
    return _tokensGenerated / (_generationStopwatch.elapsedMilliseconds / 1000);
  }

  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    embeddingModel?.close();
    super.dispose();
  }
}

enum GemmaServiceState {
  uninitialized,
  downloading,
  downloaded,
  embedderDownloaded,
  loading,
  ready,
  generating,
  error,
}
