import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_mobile/core/providers/ai_providers.dart';
import 'package:aura_mobile/core/theme/app_theme.dart';
import 'package:aura_mobile/domain/entities/model_info.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String? _error;
  String? _statusMessage;
  String? _taskId;
  // Small lightweight model for mobile
  final String _modelUrl = "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf?download=true";
  final String _modelFileName = "smollm2-360m.gguf";
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _checkExistingDownloads();
  }

  Future<void> _checkExistingDownloads() async {
    // First, check if ANY model is already downloaded (including from model selector)
    final docsDir = await getApplicationDocumentsDirectory();
    final docsFiles = Directory(docsDir.path)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.gguf'))
        .toList();

    if (docsFiles.isNotEmpty) {
      // A model exists, try to load it
      _onDownloadComplete();
      return;
    }

    // Check for active download tasks
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      // Find task matching our model URL
      final matchingTasks = tasks.where((t) => t.url == _modelUrl).toList();
      final task = matchingTasks.isNotEmpty ? matchingTasks.last : null;

      if (task == null) return;

      if (task.status == DownloadTaskStatus.complete) {
          final file = File('${docsDir.path}/$_modelFileName');
          if (await file.exists()) {
             _onDownloadComplete();
             return;
          } else {
             await FlutterDownloader.remove(taskId: task.taskId, shouldDeleteContent: true);
          }
      }

      if (task.status == DownloadTaskStatus.running ||
          task.status == DownloadTaskStatus.enqueued ||
          task.status == DownloadTaskStatus.paused) {

        setState(() {
           _taskId = task.taskId;
           _isDownloading = true;
           _statusMessage = task.status == DownloadTaskStatus.running
               ? "Resuming download... ${task.progress}%"
               : "Download Queued...";
           _progress = task.progress / 100;
        });
        _listenToDownload(task.taskId);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToDownload(String taskId) {
      final runAnywhere = ref.read(runAnywhereProvider);
      _subscription?.cancel();
      _subscription = runAnywhere.downloadUpdates.listen((update) {
          if (update.id == taskId) {
              if (mounted) {
                  setState(() {
                      _progress = update.progress / 100;
                      if (update.status == DownloadTaskStatus.running) {
                        _statusMessage = "Downloading: ${update.progress}%";
                      } else if (update.status == DownloadTaskStatus.enqueued) {
                        _statusMessage = "Queued for download...";
                        _progress = 0;
                      } else if (update.status == DownloadTaskStatus.paused) {
                        _statusMessage = "Download paused";
                      }
                  });

                  if (update.status == DownloadTaskStatus.complete) {
                      _onDownloadComplete();
                  } else if (update.status == DownloadTaskStatus.failed) {
                      setState(() {
                        _error = "Download failed. Please try again.";
                        _isDownloading = false;
                        _statusMessage = null;
                      });
                  }
              }
          }
      });
  }

  Future<void> _onDownloadComplete() async {
      setState(() {
        _statusMessage = "Initializing AI Engine...";
      });

      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final prefs = await SharedPreferences.getInstance();

        // Try to load the saved active model first
        String? activeModelId = prefs.getString('active_model_id');
        String? modelPath;

        if (activeModelId != null) {
          final activeModel = modelCatalog.where((m) => m.id == activeModelId).firstOrNull;
          if (activeModel != null) {
            final path = '${docsDir.path}/${activeModel.fileName}';
            if (File(path).existsSync()) {
              modelPath = path;
            }
          }
        }

        // Fallback: find any .gguf file
        if (modelPath == null) {
          final ggufFiles = Directory(docsDir.path)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.gguf'))
              .toList();

          if (ggufFiles.isNotEmpty) {
            modelPath = ggufFiles.first.path;
            // Try to match to catalog and save as active
            final fileName = modelPath.split('/').last;
            final matchingModel = modelCatalog.where((m) => m.fileName == fileName).firstOrNull;
            if (matchingModel != null) {
              await prefs.setString('active_model_id', matchingModel.id);
            }
          }
        }

        if (modelPath == null) {
          throw Exception('No model file found');
        }

        // Load the model
        final llmService = ref.read(llmServiceProvider);
        await llmService.loadModel(modelPath);

        // Navigate to Chat Screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/chat');
        }
      } catch (e) {
         if (mounted) {
           setState(() {
              _error = "Initialization failed: $e";
              _isDownloading = false;
           });
         }
      }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _error = null;
      _statusMessage = "Initializing download...";
    });

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelPath = '${docsDir.path}/$_modelFileName';

      // Ensure directory exists
      final modelDir = Directory(docsDir.path);
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      // Check if file exists and delete it to force fresh download if requested
      // (or let downloader resume. here we will rely on downloader, but maybe we should warn?)
      // For now, we trust flow. But let's verify path.
      final file = File(modelPath);
      if (await file.exists()) {
         // Optionally check size?
         // For now, let's just proceed. FlutterDownloader handles resumption.
      }

      // Use RunAnywhere to handle download logic including deduplication
      final runAnywhere = ref.read(runAnywhereProvider);

      final taskId = await runAnywhere.downloadModel(
        _modelUrl,
        modelPath,
      );

      if (taskId != null) {
         _taskId = taskId;
         _listenToDownload(taskId);
      } else {
         throw Exception("Failed to start download (taskId is null)");
      }

    } catch (e, stack) {
      debugPrint('Download Error: $e');
      debugPrint('Stack Trace: $stack');
      if (mounted) {
        setState(() {
          _error = "Download failed: $e";
          _isDownloading = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_for_offline, size: 80, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text(
                'Setup AI Brain',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To run offline, AURA needs to download a small AI model (~250MB). This happens only once.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.surface,
                  color: AppTheme.accent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage ?? 'Preparing...',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    if (_taskId != null) {
                       final runAnywhere = ref.read(runAnywhereProvider);
                       await runAnywhere.cancelDownload(_taskId!);
                    }
                    setState(() {
                      _isDownloading = false;
                      _statusMessage = null;
                      _progress = 0;
                    });
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You can close the app. Download continues in background.',
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                 if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Download Model',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
