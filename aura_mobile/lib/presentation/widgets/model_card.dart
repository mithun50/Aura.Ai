import 'package:flutter/material.dart';
import 'package:aura_mobile/domain/entities/model_info.dart';
import 'package:aura_mobile/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isDownloaded;
  final bool isActive;
  final bool isDownloading;
  final double downloadProgress;
  final String? error;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const ModelCard({
    super.key,
    required this.model,
    required this.isDownloaded,
    required this.isActive,
    required this.isDownloading,
    required this.downloadProgress,
    this.error,
    this.onDownload,
    this.onDelete,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.accent : AppTheme.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    model.name,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent, width: 1),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              model.description,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Specs Row
            Row(
              children: [
                _buildSpec(Icons.storage, model.sizeFormatted),
                const SizedBox(width: 16),
                _buildSpec(Icons.memory, model.ramRequirement),
                const SizedBox(width: 16),
                _buildSpec(Icons.speed, model.speed),
                if (model.hasThinking) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7c3aed).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7c3aed).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology,
                            color: const Color(0xFF7c3aed).withValues(alpha: 0.9),
                            size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Thinks',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7c3aed).withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Error Message
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Download failed',
                        style: GoogleFonts.inter(color: AppTheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Progress Bar
            if (isDownloading) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading...',
                        style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 12),
                      ),
                      Text(
                        '${(downloadProgress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ],

            // Action Buttons
            if (!isDownloading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isDownloaded)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onDownload,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (isDownloaded && !isActive) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSelect,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Select'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpec(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
