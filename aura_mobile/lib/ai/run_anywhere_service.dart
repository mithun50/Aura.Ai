import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/services.dart' show rootBundle;
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

/// Simulated RunAnywhere SDK Wrapper
/// In a real scenario, this would import the native package or platform channel.

@pragma('vm:entry-point')
class RunAnywhere {
  static final RunAnywhere _instance = RunAnywhere._internal();
  
  factory RunAnywhere() => _instance;
  
  RunAnywhere._internal();

  bool _isInitialized = false;
  double? _contextId;
  String? _currentModelPath;

  final _downloadStreamController = StreamController<DownloadUpdate>.broadcast();
  Stream<DownloadUpdate> get downloadUpdates => _downloadStreamController.stream;
  
  final ReceivePort _port = ReceivePort();



  /// Download model from URL to local path
  /// Returns the taskId for the download
  Future<String?> downloadModel(String url, String destinationPath) async {
    print('RunAnywhere: downloadModel called for $url');
    if (!_isInitialized) {
        await initialize();
    }

    final tasks = await FlutterDownloader.loadTasks();
    final fileName = destinationPath.split('/').last;
    final saveDir = destinationPath.substring(0, destinationPath.lastIndexOf('/'));

    // Check for existing tasks to avoid duplicates
    if (tasks != null) {
      var activeTasks = tasks.where((task) => 
        task.url == url && 
        (task.status == DownloadTaskStatus.running || 
         task.status == DownloadTaskStatus.enqueued || 
         task.status == DownloadTaskStatus.paused)
      ).toList();

      if (activeTasks.isNotEmpty) {
        if (activeTasks.length == 1) {
          print('RunAnywhere: Found existing active task: ${activeTasks.first.taskId}');
          return activeTasks.first.taskId;
        } else {
          print('RunAnywhere: Found multiple active tasks (${activeTasks.length}). Cleaning up...');
          // Cancel all to prevent corruption and start fresh
          for (var task in activeTasks) {
            await FlutterDownloader.cancel(taskId: task.taskId);
          }
          // Fall through to create new task
        }
      }
    }

    if (kDebugMode) print('RunAnywhere: Starting download: $url -> $saveDir/$fileName');

    try {
        final taskId = await FlutterDownloader.enqueue(
          url: url,
          savedDir: saveDir,
          fileName: fileName,
          showNotification: true,
          openFileFromNotification: false,
          saveInPublicStorage: false,
        );
        print('RunAnywhere: Enqueue success, taskId: $taskId');
        return taskId;
    } catch (e) {
        print('RunAnywhere: Enqueue failed: $e');
        rethrow;
    }
  }

  /// Cancel a specific download task
  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  /// Initialize the engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      print('RunAnywhere: Initializing...');
    }
    
    // Register background isolate communication for downloader
    // Clean up existing mapping to prevent "Port already registered" error on hot restart
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    
    _port.listen((dynamic data) {
       String id = data[0];
       int status = data[1];
       int progress = data[2];
       _downloadStreamController.add(DownloadUpdate(id, DownloadTaskStatus.fromInt(status), progress));
    });

    await FlutterDownloader.registerCallback(RunAnywhere.downloadCallback);

    // Sync existing tasks
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      for (var task in tasks) {
        // Only track relevant tasks to avoid noise
        if (task.status == DownloadTaskStatus.running || 
            task.status == DownloadTaskStatus.enqueued ||
            task.status == DownloadTaskStatus.paused ||
            task.status == DownloadTaskStatus.complete) {
            
             if (kDebugMode) {
               print('RunAnywhere: Found existing task ${task.taskId} status: ${task.status}');
             }
             _downloadStreamController.add(DownloadUpdate(task.taskId, task.status, task.progress));
        }
      }
    }

    _isInitialized = true;
  }

  /// Get active task ID for a given URL
  Future<String?> getTaskIdForUrl(String url) async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return null;
    
    try {
        final task = tasks.firstWhere((t) => t.url == url && (
            t.status == DownloadTaskStatus.running || 
            t.status == DownloadTaskStatus.enqueued ||
            t.status == DownloadTaskStatus.paused
        ));
        return task.taskId;
    } catch (e) {
        return null;
    }
  }

  /// Load model into memory
  Future<void> loadModel(String modelPath) async {
    if (!_isInitialized) await initialize();
    
    String finalPath = modelPath;

    // Handle Asset Path
    if (modelPath.startsWith('assets/')) {
      final docsDir = await getApplicationDocumentsDirectory();
      final filename = modelPath.split('/').last;
      final file = File('${docsDir.path}/$filename');
      
      if (!await file.exists()) {
        if (kDebugMode) print('Copying model from assets to ${file.path}...');
        try {
          final byteData = await rootBundle.load(modelPath);
          await file.writeAsBytes(byteData.buffer.asUint8List(
            byteData.offsetInBytes, 
            byteData.lengthInBytes
          ));
        } catch (e) {
          throw Exception('Failed to load model asset: $modelPath. Details: $e');
        }
      }
      finalPath = file.path;
    }

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
        _contextId = null;
      } catch (e) {
        print('Warning: Failed to release previous context: $e');
      }
    }
    
    try {
      if (kDebugMode) print('Loading Llama model from $finalPath...');
      
      final result = await Fllama.instance()?.initContext(
        finalPath,
        useMmap: true,
        useMlock: false,
        nGpuLayers: 0, // Default to CPU or auto
      );

      if (result != null) {
          if (kDebugMode) print('Init Context Result: $result');
          // Try to find context ID from result map
          if (result.containsKey('contextId')) {
            _contextId = (result['contextId'] as num).toDouble();
          } else if (result.containsKey('id')) {
             _contextId = (result['id'] as num).toDouble();
          } else {
             print("Warning: Context ID not found in result.");
          }
      } else {
          throw Exception("Fllama initContext returned null");
      }
      
      _currentModelPath = finalPath;
      
      if (kDebugMode) print('Llama model loaded successfully. Context ID: $_contextId');
    } catch (e) {
      print('CRITICAL: Failed to initialize Llama: $e');
      throw Exception('Failed to load native Llama engine. Error: $e');
    }
  }

  /// Chat with the model (streaming)
  Stream<String> chat({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 256,
  }) async* {
    if (!_isInitialized) throw Exception('RunAnywhere not initialized');
    if (_contextId == null) throw Exception('No model loaded');

    final fullPrompt = systemPrompt != null 
        ? '$systemPrompt\n\nUser: $prompt\nAssistant:' 
        : 'User: $prompt\nAssistant:';

    final controller = StreamController<String>();
    
    // Listen to global token stream
    final subscription = Fllama.instance()?.onTokenStream?.listen((data) {
        if (data.containsKey('token')) {
            final token = data['token'] as String?;
            if (token != null) {
                controller.add(token);
            }
        }
    });

    try {
      await Fllama.instance()?.completion(
        _contextId!,
        prompt: fullPrompt,
        stop: ["User:", "\nUser", "System:"],
        temperature: 0.7,
        topP: 0.9,
        nPredict: maxTokens,
        emitRealtimeCompletion: true,
      );
    } catch (e) {
      print('Error during inference: $e');
      controller.add(" [Error: $e]");
    } finally {
       await subscription?.cancel();
       controller.close();
    }
    
    yield* controller.stream;
  }

  /// Generate embeddings for a given text
  Future<List<double>> getEmbeddings(String text) async {
    if (!_isInitialized) throw Exception('RunAnywhere not initialized');
    return [];
  }

  void dispose() {
    if (_contextId != null) {
        Fllama.instance()?.releaseContext(_contextId!);
        _contextId = null;
    }
  }
}

