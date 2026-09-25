import 'dart:io';

import 'package:flutter/material.dart';

import '../services/update_service.dart';
import 'package:budgetbuddy/core/utils/alert_dialog.dart';

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
  bool _needsInstallPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final canInstall = await UpdateService.instance.canRequestPackageInstalls();
    if (!canInstall && mounted) {
      setState(() {
        _needsInstallPermission = true;
      });
    }
  }

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
        final isPermissionError = errorMsg.contains('REQUEST_INSTALL_PACKAGES') ||
            errorMsg.toLowerCase().contains('permission_denied') ||
            errorMsg.toLowerCase().contains('permission denied');

        if (isPermissionError) {
          setState(() {
            _needsInstallPermission = true;
          });
        }

        showAppAlert(context, message: isPermissionError
                  ? 'Permission required: Please allow "Install unknown apps" for Budget Buddy in Settings.'
                  : 'Installation intent: $errorMsg', title: 'Notice', icon: Icons.info_outline_rounded,


        );
      } else if (mounted) {
        setState(() {
          _needsInstallPermission = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showAppAlert(context, message: 'Failed to open installer: $e', title: 'Notice', icon: Icons.info_outline_rounded,

        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = widget.updateInfo;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
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
                        color: const Color(0xFF991B1B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Color(0xFF991B1B),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Required',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF991B1B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF991B1B),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 11,
                                      color: Color(0xFF991B1B),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Mandatory',
                                      style: TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
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
                const SizedBox(height: 14),

                // Mandatory Update Notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF991B1B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF991B1B).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF991B1B), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You must update Budget Buddy to continue using the application.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Install Permission Warning Card (if needed)
                if (_needsInstallPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD97706),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security_rounded,
                                color: Color(0xFFD97706), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Permission Required to Install',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Android requires you to enable "Allow from this source" in Settings before updates can be installed.',
                          style: TextStyle(fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              await UpdateService.instance
                                  .openInstallPermissionSettings();
                              await Future<void>.delayed(
                                  const Duration(milliseconds: 600));
                              final canInstall = await UpdateService.instance
                                  .canRequestPackageInstalls();
                              if (mounted) {
                                setState(() {
                                  _needsInstallPermission = !canInstall;
                                });
                              }
                            },
                            icon: const Icon(Icons.settings_suggest_rounded,
                                size: 18),
                            label: const Text(
                              'Open Settings & Allow',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Changelog Section
                Text(
                  "What's New in v${info.version}",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
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
                const SizedBox(height: 18),

                // Download Progress or Error State
                if (_state == UpdateDownloadState.downloading) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Downloading APK update...',
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
                              color: const Color(0xFF0F766E),
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
                          color: const Color(0xFF0F766E),
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
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Download complete! Ready to install.',
                            style: TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
                      color: const Color(0xFF991B1B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF991B1B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFF991B1B), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage ?? 'Download failed.',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                  children: [
                    if (_state == UpdateDownloadState.downloading) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF991B1B),
                            side: const BorderSide(color: Color(0xFF991B1B)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _state = UpdateDownloadState.idle;
                            });
                          },
                          child: const Text('Cancel Download'),
                        ),
                      ),
                    ] else if (_state == UpdateDownloadState.downloaded) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (_downloadedApk != null) {
                              _installApk(_downloadedApk!);
                            }
                          },
                          icon: const Icon(Icons.install_mobile_rounded, size: 20),
                          label: const Text(
                            'Install Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _startDownload,
                          icon: const Icon(Icons.system_update_rounded, size: 20),
                          label: Text(
                            _state == UpdateDownloadState.error
                                ? 'Retry Update'
                                : 'Update Now',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




