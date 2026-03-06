import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_config.dart';
import '../ui/app_colors.dart';

class UpdateService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const _skippedVersionKey = 'update_skipped_version';

  /// Проверяет версию приложения и при необходимости показывает диалог.
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);

      final platform = Platform.isIOS ? 'ios' : 'android';

      final response = await _dio.get('${ApiConfig.baseUrl}/app-version');
      final data = response.data as Map<String, dynamic>;
      final cfg = data[platform] as Map<String, dynamic>?;
      if (cfg == null) return;

      final latestStr = cfg['latestVersion'] as String? ?? '0.0.0';
      final minVersion = _parseVersion(cfg['minVersion'] as String? ?? '0.0.0');
      final latestVersion = _parseVersion(latestStr);
      final storeUrl = cfg['storeUrl'] as String? ?? '';
      final rustoreUrl = cfg['rustoreUrl'] as String?;
      final downloadUrl = cfg['downloadUrl'] as String?;

      final isForced = _compare(current, minVersion) < 0;
      final hasUpdate = _compare(current, latestVersion) < 0;

      if (!isForced && !hasUpdate) return;

      // Для мягкого обновления — проверяем, не пропустил ли пользователь эту версию
      if (!isForced) {
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_skippedVersionKey);
        if (skipped == latestStr) return; // уже пропустил эту версию
      }

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: !isForced,
        builder: (_) => _UpdateDialog(
          isForced: isForced,
          latestVersionStr: latestStr,
          storeUrl: storeUrl,
          rustoreUrl: rustoreUrl,
          downloadUrl: downloadUrl,
        ),
      );
    } catch (_) {
      // Не мешаем работе приложения при ошибке сети
    }
  }

  /// Сохраняет пропущенную версию
  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  /// Разбирает "1.2.3" → [1, 2, 3]
  static List<int> _parseVersion(String v) {
    return v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  /// Сравнивает две версии: -1 (a<b), 0 (a==b), 1 (a>b)
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

class _UpdateDialog extends StatelessWidget {
  final bool isForced;
  final String latestVersionStr;
  final String storeUrl;
  final String? rustoreUrl;
  final String? downloadUrl;

  const _UpdateDialog({
    required this.isForced,
    required this.latestVersionStr,
    required this.storeUrl,
    this.rustoreUrl,
    this.downloadUrl,
  });

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasRustore =
        !Platform.isIOS && rustoreUrl != null && rustoreUrl!.isNotEmpty;
    final hasDownload =
        !Platform.isIOS && downloadUrl != null && downloadUrl!.isNotEmpty;

    return PopScope(
      canPop: !isForced,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.brandPrimary,
                      context.brandSecondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                isForced
                    ? 'Требуется обновление'
                    : 'Доступно обновление',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isForced
                    ? 'Эта версия приложения устарела.\nПожалуйста, обновите приложение, чтобы продолжить работу.'
                    : 'Вышла новая версия приложения с улучшениями и исправлениями.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary.withValues(alpha: 0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // iOS — App Store, Android — только RuStore
              if (Platform.isIOS)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _open(storeUrl),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: context.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Открыть App Store',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else ...[
                if (hasRustore)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _open(rustoreUrl!),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: context.brandPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Открыть RuStore',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (hasDownload) ...[
                  if (hasRustore) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _open(downloadUrl!),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: context.brandPrimary),
                        foregroundColor: context.brandPrimary,
                      ),
                      child: const Text(
                        'Скачать APK',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],

              // Кнопка «Позже» только если обновление не принудительное
              if (!isForced) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    UpdateService.skipVersion(latestVersionStr);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Напомнить позже',
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
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
