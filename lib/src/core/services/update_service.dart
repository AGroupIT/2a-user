import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_config.dart';
import '../ui/app_colors.dart';

/// Info about an available update for the current platform.
class UpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  final String rustoreUrl;
  final int size;
  final String sha256;
  final String changelog;
  final bool isForced;

  const UpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.downloadUrl,
    required this.rustoreUrl,
    required this.size,
    required this.sha256,
    required this.changelog,
    required this.isForced,
  });
}

class UpdateService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static bool _isDialogShowing = false;
  static const _kDismissedVersionKey = 'update_dismissed_version';
  static const _kDismissedAtKey = 'update_dismissed_at';
  static const _distribution = String.fromEnvironment(
    'APP_DISTRIBUTION',
    defaultValue: 'direct',
  );

  /// Check for update and return [UpdateInfo] if available.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return null;
      if (Platform.isAndroid && _distribution == 'rustore') return null;

      final info = await PackageInfo.fromPlatform();
      final currentStr = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      final current = _parseVersion(currentStr);
      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await _dio.get(
        '${ApiConfig.baseUrl}/app-version?app=user',
      );
      final data = response.data as Map<String, dynamic>;
      final cfg = data[platform] as Map<String, dynamic>?;
      if (cfg == null) return null;

      final minVersionStr = cfg['minVersion'] as String? ?? '0.0.0';
      final latestVersionStr = cfg['latestVersion'] as String? ?? '0.0.0';
      final minVersion = _parseVersion(minVersionStr);
      final latestVersion = _parseVersion(latestVersionStr);

      final isForced = _compare(current, minVersion) < 0;
      final hasUpdate = _compare(current, latestVersion) < 0;

      if (!isForced && !hasUpdate) return null;

      final downloadUrl = cfg['downloadUrl'] as String? ?? '';
      return UpdateInfo(
        latestVersion: latestVersionStr,
        minVersion: minVersionStr,
        downloadUrl: downloadUrl,
        rustoreUrl: cfg['rustoreUrl'] as String? ?? '',
        size: cfg['size'] as int? ?? 0,
        sha256: cfg['sha256'] as String? ?? '',
        changelog: cfg['changelog'] as String? ?? '',
        isForced: isForced,
      );
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  /// Check and show dialog (called from app_shell).
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_isDialogShowing) return;

    final update = await checkForUpdate();
    if (update == null) return;
    if (!context.mounted) return;

    // Skip if user dismissed this version recently (24h cooldown) — unless forced
    if (!update.isForced) {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_kDismissedVersionKey);
      final dismissedAt = prefs.getInt(_kDismissedAtKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (dismissed == update.latestVersion &&
          now - dismissedAt < 24 * 60 * 60 * 1000) {
        return;
      }
    }

    if (!context.mounted) return;
    _isDialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !update.isForced,
      builder: (_) => UpdateDialog(update: update),
    );

    _isDialogShowing = false;
  }

  /// Record that user dismissed this version.
  static Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedVersionKey, version);
    await prefs.setInt(_kDismissedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Download the update file with progress callback.
  /// Returns the path to the downloaded file.
  static Future<String> downloadUpdate(
    UpdateInfo update, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = Directory(
      '${(await getApplicationCacheDirectory()).path}/updates',
    );

    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Clean up old downloads
    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.apk')) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }

    final filePath = '${dir.path}/2a-user-${update.latestVersion}.apk';
    final partPath = '$filePath.part';

    // Check for partial download (resume)
    int existingBytes = 0;
    final partFile = File(partPath);
    if (partFile.existsSync()) {
      existingBytes = partFile.lengthSync();
    }
    final downloadUrl = update.downloadUrl;

    final downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    await downloadDio.download(
      downloadUrl,
      partPath,
      cancelToken: cancelToken,
      deleteOnError: false,
      options: Options(
        headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
      ),
      onReceiveProgress: (received, total) {
        final actualReceived = received + existingBytes;
        final actualTotal = total > 0 ? total + existingBytes : update.size;
        onProgress(actualReceived, actualTotal);
      },
    );

    // Rename .part → final
    final finalFile = partFile.renameSync(filePath);

    // Verify SHA256 if provided
    if (update.sha256.isNotEmpty) {
      final bytes = finalFile.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      if (hash != update.sha256) {
        finalFile.deleteSync();
        throw Exception(
          'SHA256 mismatch: expected ${update.sha256}, got $hash',
        );
      }
    }

    return filePath;
  }

  /// Install the downloaded update.
  static Future<void> installUpdate(String filePath) async {
    if (Platform.isAndroid) {
      await _installAndroid(filePath);
    }
  }

  // ── Android: trigger system package installer ──

  static const _channel = MethodChannel('com.twoalogistic.user/update');
  static Future<void> _installAndroid(String apkPath) async {
    final canInstall =
        await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    if (!canInstall) {
      await _channel.invokeMethod('openInstallSettings');
      await Future.delayed(const Duration(seconds: 3));
      final canNow =
          await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!canNow) {
        throw Exception(
          ApiConfig.isUsingHkProxy
              ? '请在设置中允许从此来源安装应用'
              : 'Разрешите установку из этого источника в настройках',
        );
      }
    }

    await _channel.invokeMethod('installApk', {'path': apkPath});
  }

  // ── Version comparison helpers ──

  /// Парсит версию "1.2.3" или "1.2.3+40" → [1, 2, 3, 40]
  static List<int> _parseVersion(String v) {
    final parts = v.split('+');
    final semver = parts[0]
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    if (parts.length > 1) {
      semver.add(int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);
    }
    return semver;
  }

  static int _compare(List<int> a, List<int> b) {
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai < bi) return -1;
      if (ai > bi) return 1;
    }
    return 0;
  }
}

// ─── Update Dialog ─────────────────────────────────────────────────

class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;

  const UpdateDialog({super.key, required this.update});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _error;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    _cancelToken = CancelToken();

    try {
      final filePath = await UpdateService.downloadUpdate(
        widget.update,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _progress = total > 0 ? received / total : 0;
            });
          }
        },
        cancelToken: _cancelToken,
      );

      if (!mounted) return;

      // Install
      await UpdateService.installUpdate(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (mounted) {
        final isZh = Localizations.localeOf(context).languageCode == 'zh';
        setState(() {
          _downloading = false;
          _error = isZh ? '下载失败：${e.message}' : 'Ошибка загрузки: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        final isZh = Localizations.localeOf(context).languageCode == 'zh';
        setState(() {
          _downloading = false;
          _error = isZh ? '错误：$e' : 'Ошибка: $e';
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _t(BuildContext context, String ru, String zh) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh' ? zh : ru;
  }

  @override
  Widget build(BuildContext context) {
    final hasRustore = !Platform.isIOS && widget.update.rustoreUrl.isNotEmpty;
    final hasDownload = !Platform.isIOS && widget.update.downloadUrl.isNotEmpty;

    return PopScope(
      canPop: !widget.update.isForced,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.update.isForced
                    ? _t(context, 'Требуется обновление', '需要更新')
                    : _t(
                        context,
                        'Доступно обновление v${widget.update.latestVersion}',
                        '有新版本 v${widget.update.latestVersion}',
                      ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                widget.update.isForced
                    ? _t(
                        context,
                        'Эта версия приложения устарела.\nПожалуйста, обновите, чтобы продолжить.',
                        '当前版本已过期。\n请更新应用以继续使用。',
                      )
                    : _t(
                        context,
                        'Вышла новая версия с улучшениями.',
                        '新版本已发布，包含改进和修复。',
                      ),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary.withValues(alpha: 0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              // Changelog
              if (widget.update.changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.update.changelog,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],

              // File size
              if (widget.update.size > 0 && !_downloading) ...[
                const SizedBox(height: 8),
                Text(
                  _t(
                    context,
                    'Размер: ${_formatBytes(widget.update.size)}',
                    '大小：${_formatBytes(widget.update.size)}',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],

              const SizedBox(height: 20),

              // Download progress
              if (_downloading) ...[
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(context.brandPrimary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Text(
                  _totalBytes > 0
                      ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}  (${(_progress * 100).toStringAsFixed(0)}%)'
                      : _t(context, 'Загрузка...', '下载中...'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _cancelToken?.cancel();
                    setState(() => _downloading = false);
                  },
                  child: Text(_t(context, 'Отмена', '取消')),
                ),
              ],

              // Error
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_t(context, 'Повторить', '重试')),
                  ),
                ),
              ],

              // Buttons (not downloading, no error)
              if (!_downloading && _error == null) ...[
                // iOS — App Store
                if (Platform.isIOS)
                  _buildButton(
                    context,
                    _t(context, 'Открыть App Store', '打开 App Store'),
                    filled: true,
                    onPressed: () {}, // TODO: storeUrl
                  )
                else ...[
                  // Android: in-app download (primary)
                  if (hasDownload)
                    _buildButton(
                      context,
                      _t(context, 'Обновить', '立即更新'),
                      filled: true,
                      onPressed: _startDownload,
                    ),
                  // RuStore as secondary option
                  if (hasRustore) ...[
                    if (hasDownload) const SizedBox(height: 10),
                    _buildButton(
                      context,
                      _t(context, 'Открыть RuStore', '打开 RuStore'),
                      filled: !hasDownload,
                      onPressed: () => _openUrl(widget.update.rustoreUrl),
                    ),
                  ],
                ],
                if (!widget.update.isForced) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      UpdateService.dismissVersion(widget.update.latestVersion);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      _t(context, 'Напомнить позже', '稍后提醒'),
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String text, {
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: context.brandPrimary),
                foregroundColor: context.brandPrimary,
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    // Using url_launcher would require import; use platform channel instead
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
