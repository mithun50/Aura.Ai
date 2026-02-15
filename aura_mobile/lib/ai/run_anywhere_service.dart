import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadUpdate {
  final String id;
  final DownloadTaskStatus status;
  final int progress;
  DownloadUpdate(this.id, this.status, this.progress);
}

@pragma('vm:entry-point')
class RunAnywhere {
  static final RunAnywhere _instance = RunAnywhere._internal();

  factory RunAnywhere() => _instance;

  RunAnywhere._internal();

  bool _isInitialized = false;
  String? _currentModelPath;
  LlamaCppChatRepository? _chatRepo;
  StreamSubscription? _chatStreamSubscription;
  Completer<void>? _loadModelLock;
  bool _stopRequested = false;
  bool _isGenerating = false;

  final _downloadStreamController =
      StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get downloadUpdates =>
      _downloadStreamController.stream;

  final ReceivePort _port = ReceivePort();

  /// Whether a model is currently loaded and ready for inference
  bool get isModelLoaded => _currentModelPath != null && _chatRepo != null;
  bool get isGenerating => _isGenerating;
  String? get currentModelPath => _currentModelPath;

  /// Stop the current generation
  void stopGeneration() {
    _stopRequested = true;
    _chatStreamSubscription?.cancel();
    _isGenerating = false;
    if (kDebugMode) debugPrint('RunAnywhere: Stop generation requested');
  }

  // ==================== DOWNLOAD MANAGEMENT ====================

  Future<String?> downloadModel(String url, String destinationPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    final tasks = await FlutterDownloader.loadTasks();
    final fileName = destinationPath.split('/').last;
    final saveDir =
        destinationPath.substring(0, destinationPath.lastIndexOf('/'));

    // Check for existing tasks to avoid duplicates
    if (tasks != null) {
      var activeTasks = tasks
          .where((task) =>
              task.url == url &&
              (task.status == DownloadTaskStatus.running ||
                  task.status == DownloadTaskStatus.enqueued ||
                  task.status == DownloadTaskStatus.paused))
          .toList();

      if (activeTasks.isNotEmpty) {
        if (activeTasks.length == 1) {
          if (kDebugMode) {
            debugPrint(
                'RunAnywhere: Found existing active task: ${activeTasks.first.taskId}');
          }
          return activeTasks.first.taskId;
        } else {
          if (kDebugMode) {
            debugPrint(
                'RunAnywhere: Found multiple active tasks (${activeTasks.length}). Cleaning up...');
          }
          for (var task in activeTasks) {
            await FlutterDownloader.cancel(taskId: task.taskId);
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint('RunAnywhere: Starting download: $url -> $saveDir/$fileName');
    }

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: saveDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );
      if (kDebugMode) debugPrint('RunAnywhere: Enqueue success, taskId: $taskId');
      return taskId;
    } catch (e) {
      if (kDebugMode) debugPrint('RunAnywhere: Enqueue failed: $e');
      rethrow;
    }
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) debugPrint('RunAnywhere: Initializing...');

    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');

    _port.listen((dynamic data) {
      String id = data[0];
      int status = data[1];
      int progress = data[2];
      _downloadStreamController
          .add(DownloadUpdate(id, DownloadTaskStatus.fromInt(status), progress));
    });

    await FlutterDownloader.registerCallback(RunAnywhere.downloadCallback);

    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      for (var task in tasks) {
        if (task.status == DownloadTaskStatus.running ||
            task.status == DownloadTaskStatus.enqueued ||
            task.status == DownloadTaskStatus.paused ||
            task.status == DownloadTaskStatus.complete) {
          if (kDebugMode) {
            debugPrint(
                'RunAnywhere: Found existing task ${task.taskId} status: ${task.status}');
          }
          _downloadStreamController
              .add(DownloadUpdate(task.taskId, task.status, task.progress));
        }
      }
    }

    _isInitialized = true;
  }

  Future<String?> getTaskIdForUrl(String url) async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return null;

    try {
      final task = tasks.firstWhere((t) =>
          t.url == url &&
          (t.status == DownloadTaskStatus.running ||
              t.status == DownloadTaskStatus.enqueued ||
              t.status == DownloadTaskStatus.paused));
      return task.taskId;
    } catch (e) {
      return null;
    }
  }

  // ==================== MODEL LOADING (llm_llamacpp) ====================

  Future<void> loadModel(String modelPath) async {
    // Mutex: prevent parallel model loading
    if (_loadModelLock != null) {
      await _loadModelLock!.future;
    }
    _loadModelLock = Completer<void>();

    try {
      if (!_isInitialized) await initialize();

      String finalPath = modelPath;

      if (!File(finalPath).existsSync()) {
        await Future.delayed(const Duration(seconds: 1));
        if (!File(finalPath).existsSync()) {
          throw Exception('Model file not found at $finalPath');
        }
      }

      // Dispose previous repo if any
      if (_chatRepo != null) {
        try {
          _chatRepo!.dispose();
        } catch (e) {
          if (kDebugMode) debugPrint('RunAnywhere: Error disposing old repo: $e');
        }
        _chatRepo = null;
        _currentModelPath = null;
      }

      if (kDebugMode) debugPrint('RunAnywhere: Loading model from $finalPath');

      _chatRepo = LlamaCppChatRepository(
        contextSize: 2048,
        batchSize: 512,
      );

      await _chatRepo!.loadModel(finalPath);
      _currentModelPath = finalPath;

      if (kDebugMode) debugPrint('RunAnywhere: Model loaded successfully');
    } catch (e) {
      _chatRepo?.dispose();
      _chatRepo = null;
      _currentModelPath = null;
      rethrow;
    } finally {
      _loadModelLock!.complete();
      _loadModelLock = null;
    }
  }

  // ==================== CHAT INFERENCE (llm_llamacpp) ====================

  /// Special tokens to filter from model output (safety net)
  static const _specialTokens = [
    '<|im_start|>', '<|im_end|>', '<|endoftext|>', '</s>',
    '<|im_start|>assistant', '<|im_start|>user', '<|im_start|>system',
    '<s>', '<|begin_of_text|>', '<|end_of_text|>',
  ];

  Stream<String> chat({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    int contextSize = 2048,
  }) {
    if (_chatRepo == null || _currentModelPath == null) {
      return Stream.error(Exception('No model loaded. Please select a model first.'));
    }

    _stopRequested = false;
    _isGenerating = true;
    final controller = StreamController<String>();

    final messages = <LLMMessage>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        LLMMessage(role: LLMRole.system, content: systemPrompt),
      LLMMessage(role: LLMRole.user, content: prompt),
    ];

    _chatStreamSubscription?.cancel();

    try {
      final stream = _chatRepo!.streamChatWithGenerationOptions(
        'aura',
        messages: messages,
        generationOptions: GenerationOptions(
          temperature: temperature,
          maxTokens: maxTokens,
          topP: 0.9,
          repeatPenalty: 1.1,
        ),
      );

      _chatStreamSubscription = stream.listen(
        (chunk) {
          if (_stopRequested) {
            _chatStreamSubscription?.cancel();
            _isGenerating = false;
            if (!controller.isClosed) controller.close();
            return;
          }

          final token = chunk.message?.content ?? '';
          if (token.isNotEmpty && !controller.isClosed) {
            // Filter special tokens as safety net
            String cleaned = token;
            for (final special in _specialTokens) {
              cleaned = cleaned.replaceAll(special, '');
            }
            if (cleaned.isNotEmpty) {
              controller.add(cleaned);
            }
          }
        },
        onDone: () {
          _isGenerating = false;
          if (!controller.isClosed) controller.close();
        },
        onError: (e) {
          _isGenerating = false;
          if (!controller.isClosed) {
            controller.addError(e);
            controller.close();
          }
        },
      );
    } catch (e) {
      _isGenerating = false;
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  // ==================== CLEANUP ====================

  void dispose() {
    _chatStreamSubscription?.cancel();
    _chatRepo?.dispose();
    _chatRepo = null;
    _currentModelPath = null;
    _downloadStreamController.close();
  }
}
