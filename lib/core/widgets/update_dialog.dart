import 'dart:io';

import 'package:flutter/material.dart';

import '../services/update_service.dart';

enum UpdateDownloadState { idle, downloading, downloaded, error }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.currentVersion,
  });

  final AppUpdateInfo updateInfo;
  final AppVersion? currentVersion;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDownloadState _state = UpdateDownloadState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  File? _downloadedApk;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateDownloadState.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.updateInfo.fileSize ?? 0;
      _errorMessage = null;
    });

    try {
      final file = await UpdateService.instance.downloadApk(
        widget.updateInfo.downloadUrl,
        onProgress: (received, total, progress) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _progress = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (file != null && await file.exists()) {
        setState(() {
          _downloadedApk = file;
          _state = UpdateDownloadState.downloaded;
        });

        // Automatically trigger installer
        _installApk(file);
      } else {
        setState(() {
          _state = UpdateDownloadState.error;
          _errorMessage = 'Downloaded file could not be verified.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = UpdateDownloadState.error;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _installApk(File file) async {
    try {
      final errorMsg = await UpdateService.instance.installApk(file);
      if (errorMsg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation intent: $errorMsg'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open installer: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = widget.updateInfo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${info.version}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (info.formattedFileSize.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                info.formattedFileSize,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Changelog Section
              Text(
                "What's New",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes.trim().isEmpty
                        ? 'Performance improvements and bug fixes.'
                        : info.releaseNotes.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Download Progress or Error State
              if (_state == UpdateDownloadState.downloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading APK...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _totalBytes > 0
                              ? '${(_progress * 100).toInt()}%'
                              : _formatBytes(_receivedBytes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _totalBytes > 0 ? _progress : null,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_totalBytes > 0)
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.labelSmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_state == UpdateDownloadState.downloaded) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Download complete! Ready to install.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_state == UpdateDownloadState.error) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage ?? 'Download failed.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!info.mandatory && _state != UpdateDownloadState.downloading)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Later'),
                    ),
                  const SizedBox(width: 8),
                  if (_state == UpdateDownloadState.idle ||
                      _state == UpdateDownloadState.error)
                    FilledButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_state == UpdateDownloadState.error
                          ? 'Retry'
                          : 'Download & Install'),
                    )
                  else if (_state == UpdateDownloadState.downloaded)
                    FilledButton.icon(
                      onPressed: () {
                        if (_downloadedApk != null) {
                          _installApk(_downloadedApk!);
                        }
                      },
                      icon: const Icon(Icons.install_mobile_rounded, size: 18),
                      label: const Text('Install Now'),
                    )
                  else if (_state == UpdateDownloadState.downloading)
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _state = UpdateDownloadState.idle;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
