import 'package:flutter/material.dart';
import 'package:aura_mobile/domain/entities/model_info.dart';
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
        gradient: LinearGradient(
          colors: isActive
              ? [
                  const Color(0xFF1a1a2e).withOpacity(0.9),
                  const Color(0xFF16213e).withOpacity(0.9),
                ]
              : [
                  const Color(0xFF0f0f1e).withOpacity(0.7),
                  const Color(0xFF1a1a2e).withOpacity(0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFe6cf8e)
              : const Color(0xFF2a2a3e),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFe6cf8e).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Color(0xFFe6cf8e),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    model.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFe6cf8e).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFe6cf8e),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFe6cf8e),
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
                color: Colors.white70,
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
              ],
            ),

            // Error Message
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Download failed',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontSize: 12,
                        ),
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
                        style: GoogleFonts.inter(
                          color: const Color(0xFFe6cf8e),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(downloadProgress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFe6cf8e),
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
                      backgroundColor: const Color(0xFF2a2a3e),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFe6cf8e),
                      ),
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
                          backgroundColor: const Color(0xFFe6cf8e),
                          foregroundColor: const Color(0xFF0a0a0c),
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
                          backgroundColor: const Color(0xFFe6cf8e),
                          foregroundColor: const Color(0xFF0a0a0c),
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
        Icon(icon, color: const Color(0xFFe6cf8e), size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
