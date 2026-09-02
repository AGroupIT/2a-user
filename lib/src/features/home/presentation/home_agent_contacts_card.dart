import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/utils/locale_text.dart';
import '../../profile/data/profile_provider.dart';

/// Компактные контакты компании для главной страницы.
///
/// Данные берутся из того же [AgentInfo], что и раздел компании в профиле,
/// поэтому карточка не создаёт отдельный запрос и исчезает для агентов без
/// опубликованных контактов.
class HomeAgentContactsCard extends StatelessWidget {
  const HomeAgentContactsCard({required this.agent, super.key});

  final AgentInfo agent;

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts(context);
    if (contacts.isEmpty) return const SizedBox.shrink();

    final companyName =
        _textOrNull(agent.name) ?? tr(context, ru: 'Ваша компания', zh: '您的公司');

    return Semantics(
      container: true,
      label: tr(context, ru: 'Контакты $companyName', zh: '$companyName 联系方式'),
      child: Container(
        key: const ValueKey('home-agent-contacts-card'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              offset: const Offset(0, 9),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: context.brandGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: context.brandPrimary.withValues(alpha: 0.22),
                        offset: const Offset(0, 6),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, ru: 'Контакты', zh: '联系方式'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tr(context, ru: 'На связи', zh: '联系我们'),
                    style: TextStyle(
                      color: context.brandPrimary,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 9.0;
                final columns = constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 330
                    ? 2
                    : 1;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final contact in contacts)
                      SizedBox(
                        width: itemWidth,
                        child: _HomeContactTile(
                          contact: contact,
                          onTap: () => _openLink(context, contact.uri),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_HomeContact> _contacts(BuildContext context) {
    final companyPhone = _textOrNull(agent.phone);
    final companyEmail = _textOrNull(agent.email);
    final telegramManager = _textOrNull(agent.companyTelegramUrl);
    final telegramChannel = _textOrNull(agent.companyTelegramChannelUrl);
    final whatsapp = _textOrNull(agent.companyWhatsappUrl);
    final vk = _textOrNull(agent.companyVkUrl);
    final website = _textOrNull(agent.companyWebsiteUrl);

    return [
      if (companyPhone != null)
        _HomeContact(
          icon: Icons.phone_rounded,
          label: tr(context, ru: 'Телефон', zh: '电话'),
          value: companyPhone,
          uri: Uri(scheme: 'tel', path: companyPhone),
        ),
      if (companyEmail != null)
        _HomeContact(
          icon: Icons.alternate_email_rounded,
          label: 'Email',
          value: companyEmail,
          uri: Uri(scheme: 'mailto', path: companyEmail),
        ),
      if (telegramManager != null)
        _HomeContact(
          icon: Icons.send_rounded,
          label: 'Telegram',
          value: _linkDisplayValue(telegramManager),
          uri: _messengerUri(telegramManager, isTelegram: true),
        ),
      if (telegramChannel != null)
        _HomeContact(
          icon: Icons.campaign_rounded,
          label: tr(context, ru: 'Telegram-канал', zh: 'Telegram 频道'),
          value: _linkDisplayValue(telegramChannel),
          uri: _messengerUri(telegramChannel, isTelegram: true),
        ),
      if (whatsapp != null)
        _HomeContact(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'WhatsApp',
          value: _linkDisplayValue(whatsapp),
          uri: _messengerUri(whatsapp),
        ),
      if (vk != null)
        _HomeContact(
          icon: Icons.groups_2_rounded,
          label: 'VK',
          value: _linkDisplayValue(vk),
          uri: _webUri(vk),
        ),
      if (website != null)
        _HomeContact(
          icon: Icons.language_rounded,
          label: tr(context, ru: 'Сайт', zh: '网站'),
          value: _linkDisplayValue(website),
          uri: _webUri(website),
        ),
    ];
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted || opened) return;
      AppToast.show(
        context,
        tr(context, ru: 'Не удалось открыть контакт', zh: '无法打开联系方式'),
        isError: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        tr(context, ru: 'Не удалось открыть контакт', zh: '无法打开联系方式'),
        isError: true,
      );
    }
  }

  static String? _textOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Uri _webUri(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('https://$trimmed');
  }

  static Uri _messengerUri(String value, {bool isTelegram = false}) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    if (isTelegram && !trimmed.contains('/') && !trimmed.contains('.')) {
      return Uri.parse('https://t.me/${trimmed.replaceFirst('@', '')}');
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7) return Uri.parse('https://wa.me/$digits');
    return _webUri(trimmed);
  }

  static String _linkDisplayValue(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }
}

class _HomeContactTile extends StatelessWidget {
  const _HomeContactTile({required this.contact, required this.onTap});

  final _HomeContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${contact.label}: ${contact.value}',
      child: Material(
        color: context.brandPrimary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('home-contact-${contact.label}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.brandPrimary.withValues(alpha: 0.11),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    contact.icon,
                    size: 18,
                    color: context.brandPrimary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        contact.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 11.5,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.north_east_rounded,
                  size: 15,
                  color: context.brandPrimary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContact {
  const _HomeContact({
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri uri;
}
