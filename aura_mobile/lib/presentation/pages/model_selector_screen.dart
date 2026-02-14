import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/presentation/providers/model_selector_provider.dart';
import 'package:aura_mobile/presentation/widgets/model_card.dart';
import 'package:aura_mobile/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ModelSelectorScreen extends ConsumerWidget {
  const ModelSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelSelectorProvider);
    final notifier = ref.read(modelSelectorProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.sidebar,
        elevation: 0,
        title: Text(
          'Model Manager',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accent),
            onPressed: () => notifier.refreshModels(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refreshModels(),
        backgroundColor: AppTheme.surface,
        color: AppTheme.accent,
        child: CustomScrollView(
          slivers: [
            // Storage Summary
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storage, color: AppTheme.accent, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Storage Usage',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStorageStat('Downloaded', '${state.downloadedModelIds.length}', Icons.download_done),
                        _buildStorageStat('Total Size', _formatBytes(state.totalStorageUsed), Icons.folder),
                        _buildStorageStat('Available', '${state.availableModels.length}', Icons.apps),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Active Model Info
            if (state.activeModelId != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final activeModel = state.availableModels
                                .where((m) => m.id == state.activeModelId)
                                .firstOrNull;
                            return Text(
                              'Active: ${activeModel?.name ?? 'Unknown'}',
                              style: GoogleFonts.inter(
                                color: AppTheme.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  'Available Models',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Model List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final model = state.availableModels[index];
                    return ModelCard(
                      model: model,
                      isDownloaded: state.isDownloaded(model.id),
                      isActive: state.isActive(model.id),
                      isDownloading: state.isDownloading(model.id),
                      downloadProgress: state.getProgress(model.id),
                      error: state.getError(model.id),
                      onDownload: () => notifier.downloadModel(model.id),
                      onDelete: () => _showDeleteConfirmation(
                        context,
                        model.name,
                        () => notifier.deleteModel(model.id),
                      ),
                      onSelect: () => notifier.selectModel(model.id),
                    );
                  },
                  childCount: state.availableModels.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(0)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String modelName,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Model?',
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$modelName"? This will free up storage space.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
