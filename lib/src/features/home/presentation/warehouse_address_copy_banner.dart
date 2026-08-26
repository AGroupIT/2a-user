import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';

Future<void> showWarehouseAddressCopyBanner(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => const WarehouseAddressCopyBannerContent(),
  );
}

class WarehouseAddressCopyBannerContent extends StatelessWidget {
  const WarehouseAddressCopyBannerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final title = tr(context, ru: 'Адрес склада скопирован', zh: '仓库地址已复制');
    final message = tr(
      context,
      ru:
          'После заполнения данных в китайском маркетплейсе сделайте '
          'скриншот и нажмите в блоке «Склад и маркировка» кнопку '
          '«Проверить заполнение». Приложение автоматически сравнит '
          'адрес, код клиента и телефон с данными на скриншоте.',
      zh:
          '在中国电商平台填写信息后，请截图并点击“仓库和标记”模块中的“检查填写”按钮。'
          '应用会自动比较截图中的仓库地址、客户代码和电话号码。',
    );

    final action = tr(context, ru: 'Понятно', zh: '明白了');

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Semantics(
                container: true,
                liveRegion: true,
                label: '$title. $message',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.verified_user_outlined,
                          size: 48,
                          color: context.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontFamily: 'Gilroy',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontFamily: 'Gilroy',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.done_rounded, size: 22),
                      label: Text(
                        action,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
