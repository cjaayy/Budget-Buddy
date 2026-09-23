import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/update_dialog.dart';

class AppVersion implements Comparable<AppVersion> {
  const AppVersion({required this.version, required this.buildNumber});

  final String version;
  final int buildNumber;

  static AppVersion parse(String versionStr, [int? buildNumber]) {
    String cleanVer = versionStr.trim();
    if (cleanVer.startsWith('v') || cleanVer.startsWith('V')) {
      cleanVer = cleanVer.substring(1);
    }

    int bld = buildNumber ?? 0;
    if (cleanVer.contains('+')) {
      final parts = cleanVer.split('+');
      cleanVer = parts[0];
      bld = int.tryParse(parts[1]) ?? bld;
    }

    return AppVersion(version: cleanVer, buildNumber: bld);
  }

  @override
  int compareTo(AppVersion other) {
    final v1Parts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = other.version.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < v1Parts.length ? v1Parts[i] : 0;
      final p2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }

    return buildNumber.compareTo(other.buildNumber);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => '$version+$buildNumber';
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isUpdateAvailable,
    this.publishedAt,
    this.fileSize,
    this.mandatory = false,
  });

  final String version;
  final int buildNumber;
  final String tagName;
  final String title;
  final String releaseNotes;
  final String downloadUrl;
  final bool isUpdateAvailable;
  final DateTime? publishedAt;
  final int? fileSize;
  final bool mandatory;

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String defaultOwner = 'cjaayy';
  static const String defaultRepo = 'Budget-Buddy';

  AppVersion? _cachedCurrentVersion;
  bool _hasCheckedOnLaunch = false;

  Future<AppVersion> getCurrentVersion() async {
    if (_cachedCurrentVersion != null) return _cachedCurrentVersion!;

    try {
      final jsonString = await rootBundle.loadString('version.json');
      final dynamic data = jsonDecode(jsonString);
      if (data is Map<String, dynamic>) {
        final ver = data['version']?.toString() ?? '1.0.0';
        final bld = int.tryParse(data['build_number']?.toString() ?? '1') ?? 1;
        _cachedCurrentVersion = AppVersion(version: ver, buildNumber: bld);
        return _cachedCurrentVersion!;
      }
    } catch (_) {
      // Fallback if version.json is not bundled or fails to parse
    }

    _cachedCurrentVersion = const AppVersion(version: '1.0.0', buildNumber: 1);
    return _cachedCurrentVersion!;
  }

  Future<AppUpdateInfo?> checkForUpdate({
    String owner = defaultOwner,
    String repo = defaultRepo,
  }) async {
    final current = await getCurrentVersion();

    // 1. Try GitHub Releases API
    try {
      final info = await _checkGitHubReleasesApi(owner, repo, current);
      if (info != null) return info;
    } catch (e) {
      debugPrint('[UpdateService] GitHub API check error: $e');
    }

    // 2. Fallback to raw version.json on main branch
    try {
      final info = await _checkRawVersionJson(owner, repo, current);
      if (info != null) return info;
    } catch (e) {
      debugPrint('[UpdateService] Raw version.json check error: $e');
    }

    return null;
  }

  Future<AppUpdateInfo?> _checkGitHubReleasesApi(
    String owner,
    String repo,
    AppVersion current,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'BudgetBuddy-OTA-Updater');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final dynamic json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) return null;

      final tagName = json['tag_name']?.toString() ?? '';
      final title = json['name']?.toString() ?? tagName;
      final body = json['body']?.toString() ?? 'New release available.';
      final publishedAtStr = json['published_at']?.toString();
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      String downloadUrl = '';
      int? size;

      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url']?.toString() ?? '';
            size = int.tryParse(asset['size']?.toString() ?? '');
            break;
          }
        }
      }

      if (downloadUrl.isEmpty && tagName.isNotEmpty) {
        downloadUrl = 'https://github.com/$owner/$repo/releases/download/$tagName/app-release.apk';
      }

      final remoteVer = AppVersion.parse(tagName);
      final isNewer = remoteVer.isNewerThan(current);

      return AppUpdateInfo(
        version: remoteVer.version,
        buildNumber: remoteVer.buildNumber,
        tagName: tagName,
        title: title,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        isUpdateAvailable: isNewer,
        publishedAt: publishedAt,
        fileSize: size,
      );
    } finally {
      client.close();
    }
  }

  Future<AppUpdateInfo?> _checkRawVersionJson(
    String owner,
    String repo,
    AppVersion current,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('https://raw.githubusercontent.com/$owner/$repo/main/version.json');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'BudgetBuddy-OTA-Updater');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final dynamic json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) return null;

      final verStr = json['version']?.toString() ?? '1.0.0';
      final bld = int.tryParse(json['build_number']?.toString() ?? '1') ?? 1;
      final tagName = json['tag_name']?.toString() ?? 'v$verStr';
      final title = json['title']?.toString() ?? 'Budget Buddy $tagName';
      final notes = json['release_notes']?.toString() ?? 'New release available.';
      final downloadUrl = json['download_url']?.toString() ?? '';
      final mandatory = json['mandatory'] == true;
      final publishedAtStr = json['published_at']?.toString();
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final remoteVer = AppVersion(version: verStr, buildNumber: bld);
      final isNewer = remoteVer.isNewerThan(current);

      return AppUpdateInfo(
        version: remoteVer.version,
        buildNumber: remoteVer.buildNumber,
        tagName: tagName,
        title: title,
        releaseNotes: notes,
        downloadUrl: downloadUrl,
        isUpdateAvailable: isNewer,
        publishedAt: publishedAt,
        mandatory: mandatory,
      );
    } finally {
      client.close();
    }
  }

  Future<File?> downloadApk(
    String url, {
    required void Function(int received, int total, double progress) onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final dir = await getTemporaryDirectory();
      final saveFile = File('${dir.path}/budgetbuddy_update.apk');
      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'BudgetBuddy-OTA-Updater');
      final response = await request.close();

      // Handle redirect if GitHub redirects to AWS S3
      HttpClientResponse finalResponse = response;
      if (response.isRedirect) {
        final redirectUri = response.headers.value(HttpHeaders.locationHeader);
        if (redirectUri != null) {
          final redirectReq = await client.getUrl(Uri.parse(redirectUri));
          redirectReq.headers.set('User-Agent', 'BudgetBuddy-OTA-Updater');
          finalResponse = await redirectReq.close();
        }
      }

      if (finalResponse.statusCode != 200) {
        throw HttpException('Download failed with status ${finalResponse.statusCode}');
      }

      final total = finalResponse.contentLength;
      int received = 0;
      final sink = saveFile.openWrite();

      await for (final List<int> chunk in finalResponse) {
        sink.add(chunk);
        received += chunk.length;
        final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress(received, total, progress);
      }

      await sink.flush();
      await sink.close();
      return saveFile;
    } finally {
      client.close();
    }
  }

  Future<String?> installApk(File file) async {
    try {
      final res = await OpenFile.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (res.type != ResultType.done) {
        return res.message;
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void checkOnLaunch(BuildContext context) {
    if (_hasCheckedOnLaunch) return;
    _hasCheckedOnLaunch = true;

    Future<void>.delayed(const Duration(seconds: 3), () async {
      try {
        final updateInfo = await checkForUpdate();
        if (updateInfo != null && updateInfo.isUpdateAvailable && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 8),
              content: Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Update available: v${updateInfo.version}!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.amberAccent,
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: !updateInfo.mandatory,
                    builder: (BuildContext dialogContext) =>
                        UpdateDialog(updateInfo: updateInfo),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('[UpdateService] checkOnLaunch failed silently: $e');
      }
    });
  }
}
