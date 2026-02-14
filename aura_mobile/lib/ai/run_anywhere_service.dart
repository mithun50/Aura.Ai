import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fllama/fllama.dart';
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

  final _downloadStreamController =
      StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get downloadUpdates =>
      _downloadStreamController.stream;

  final ReceivePort _port = ReceivePort();

  /// Whether a model is currently loaded and ready for inference
  bool get isModelLoaded => _currentModelPath != null;
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

    _currentModelPath = finalPath;
    if (kDebugMode) debugPrint('RunAnywhere: Model path set to $finalPath');
  }

  // ==================== CHAT INFERENCE (CORRECT fllama API) ====================

  /// Chat with the model using the correct fllamaChat() API.
  /// Returns a stream of accumulated response text chunks.
  Stream<String> chat({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    int contextSize = 2048,
  }) {
    if (_currentModelPath == null) {
      return Stream.error(Exception('No model loaded'));
    }

    final controller = StreamController<String>();

    final messages = <Message>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        Message(Role.system, systemPrompt),
      Message(Role.user, prompt),
    ];

    final request = OpenAiRequest(
      maxTokens: maxTokens,
      messages: messages,
      modelPath: _currentModelPath!,
      contextSize: contextSize,
      temperature: temperature,
      presencePenalty: 1.1,
      frequencyPenalty: 0.0,
      topP: 0.9,
    );

    String previousResponse = '';

    fllamaChat(request, (String response, String openaiJson, bool done) {
      // response is the accumulated text so far
      // Extract only the new tokens since last callback
      if (response.length > previousResponse.length) {
        final newToken = response.substring(previousResponse.length);
        previousResponse = response;
        if (!controller.isClosed) {
          controller.add(newToken);
        }
      }
      if (done) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    });

    return controller.stream;
  }

  // ==================== CLEANUP ====================

  void dispose() {
    _currentModelPath = null;
    _downloadStreamController.close();
  }
}
