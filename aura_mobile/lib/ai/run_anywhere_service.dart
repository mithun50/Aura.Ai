import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
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
  double? _contextId;
  StreamSubscription? _tokenStreamSubscription;

  final _downloadStreamController =
      StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get downloadUpdates =>
      _downloadStreamController.stream;

  final ReceivePort _port = ReceivePort();

  /// Whether a model is currently loaded and ready for inference
  bool get isModelLoaded => _currentModelPath != null && _contextId != null;
  String? get currentModelPath => _currentModelPath;

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

  // ==================== MODEL LOADING ====================

  Future<void> loadModel(String modelPath) async {
    if (!_isInitialized) await initialize();

    String finalPath = modelPath;

    if (!File(finalPath).existsSync()) {
      await Future.delayed(const Duration(seconds: 1));
      if (!File(finalPath).existsSync()) {
        throw Exception('Model file not found at $finalPath');
      }
    }

    // Release previous context if any
    if (_contextId != null) {
      try {
        await Fllama.instance()?.releaseContext(_contextId!);
      } catch (e) {
        if (kDebugMode) debugPrint('RunAnywhere: Error releasing old context: $e');
      }
    }

    // Initialize new context
    if (kDebugMode) debugPrint('RunAnywhere: Loading model from $finalPath');

    final result = await Fllama.instance()?.initContext(
      finalPath,
      nCtx: 2048,
      nBatch: 512,
      emitLoadProgress: true,
    );

    if (result != null && result.containsKey('contextId')) {
      _contextId = (result['contextId'] as num).toDouble();
      _currentModelPath = finalPath;
      if (kDebugMode) debugPrint('RunAnywhere: Model loaded, contextId=$_contextId');
    } else {
      throw Exception('Failed to initialize model context: $result');
    }
  }

  // ==================== CHAT INFERENCE (FCllama API) ====================

  /// Chat with the model using FCllama's getFormattedChat + completion API.
  /// Returns a stream of token strings.
  Stream<String> chat({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    int contextSize = 2048,
  }) {
    if (_contextId == null || _currentModelPath == null) {
      return Stream.error(Exception('No model loaded'));
    }

    final controller = StreamController<String>();
    final contextId = _contextId!;

    // Build chat messages using RoleContent
    final messages = <RoleContent>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        RoleContent(role: 'system', content: systemPrompt),
      RoleContent(role: 'user', content: prompt),
    ];

    // Cancel any previous token stream listener
    _tokenStreamSubscription?.cancel();

    // Listen for tokens from the event stream
    _tokenStreamSubscription =
        Fllama.instance()?.onTokenStream?.listen((data) {
      final function = data['function'];
      if (function == 'completion') {
        final result = data['result'];
        if (result is Map && result.containsKey('token')) {
          final token = result['token']?.toString() ?? '';
          if (token.isNotEmpty && !controller.isClosed) {
            controller.add(token);
          }
        }
      }
    });

    // Format chat and run completion
    _runCompletion(
      contextId: contextId,
      messages: messages,
      maxTokens: maxTokens,
      temperature: temperature,
    ).then((_) {
      _tokenStreamSubscription?.cancel();
      if (!controller.isClosed) controller.close();
    }).catchError((e) {
      _tokenStreamSubscription?.cancel();
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _runCompletion({
    required double contextId,
    required List<RoleContent> messages,
    required int maxTokens,
    required double temperature,
  }) async {
    // Format messages using the model's chat template
    final formattedPrompt = await Fllama.instance()?.getFormattedChat(
      contextId,
      messages: messages,
    );

    if (formattedPrompt == null || formattedPrompt.isEmpty) {
      throw Exception('Failed to format chat messages');
    }

    // Run completion with realtime token emission
    await Fllama.instance()?.completion(
      contextId,
      prompt: formattedPrompt,
      temperature: temperature,
      nPredict: maxTokens,
      topP: 0.9,
      penaltyRepeat: 1.1,
      penaltyFreq: 0.0,
      penaltyPresent: 0.0,
      emitRealtimeCompletion: true,
      stop: ['<|im_end|>', '<|endoftext|>', '</s>'],
    );
  }

  // ==================== CLEANUP ====================

  void dispose() {
    _tokenStreamSubscription?.cancel();
    if (_contextId != null) {
      Fllama.instance()?.releaseContext(_contextId!);
    }
    _currentModelPath = null;
    _contextId = null;
    _downloadStreamController.close();
  }
}
