import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/track_warehouse_delivery_repository.dart';
import '../domain/track_item.dart';

bool canShowTrackWarehouseDelivery(TrackItem track) {
  if (track.id == null) return false;
  if (track.statusCode == 'pending') return true;
  return track.statusCode.isEmpty && track.status == 'В ожидании';
}

class TrackWarehouseDeliveryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const TrackWarehouseDeliveryButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return Semantics(
      button: true,
      label: tr(context, ru: 'Статус доставки до склада', zh: '到仓物流状态'),
      child: Material(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey('warehouse-delivery-button'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, ru: 'Статус доставки до склада', zh: '到仓物流状态'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: accent, size: 23),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrackWarehouseDeliveryPanel extends ConsumerStatefulWidget {
  final TrackItem track;

  const TrackWarehouseDeliveryPanel({super.key, required this.track});

  @override
  ConsumerState<TrackWarehouseDeliveryPanel> createState() =>
      _TrackWarehouseDeliveryPanelState();
}

class _TrackWarehouseDeliveryPanelState
    extends ConsumerState<TrackWarehouseDeliveryPanel> {
  static const _pollInterval = Duration(seconds: 20);

  TrackWarehouseDelivery? _delivery;
  Timer? _pollTimer;
  bool _loading = true;
  bool _requesting = false;
  bool _automaticAttempted = false;
  String? _errorCode;

  bool get _isPending =>
      widget.track.statusCode == 'pending' || widget.track.isPending;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  @override
  void didUpdateWidget(covariant TrackWarehouseDeliveryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.statusCode != widget.track.statusCode) {
      _pollTimer?.cancel();
      _delivery = null;
      _automaticAttempted = false;
      _errorCode = null;
      unawaited(_load(initial: true));
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    final trackId = widget.track.id;
    if (trackId == null) return;
    if (initial && mounted) setState(() => _loading = true);
    try {
      final delivery = await ref
          .read(trackWarehouseDeliveryRepositoryProvider)
          .get(trackId);
      if (!mounted) return;
      setState(() {
        _delivery = delivery;
        _loading = false;
        _errorCode = null;
      });
      _configurePolling(delivery);

      if (_isPending &&
          delivery.configured &&
          !_automaticAttempted &&
          delivery.subscriptionStatus != 'active' &&
          delivery.subscriptionStatus != 'subscribing') {
        _automaticAttempted = true;
        await _request(automatic: true);
      }
    } on TrackWarehouseDeliveryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorCode = error.code ?? 'UNKNOWN';
      });
    }
  }

  Future<void> _request({required bool automatic}) async {
    final trackId = widget.track.id;
    if (trackId == null || _requesting) return;
    setState(() {
      _requesting = true;
      _errorCode = null;
    });
    try {
      final delivery = await ref
          .read(trackWarehouseDeliveryRepositoryProvider)
          .request(trackId, automatic: automatic);
      if (!mounted) return;
      setState(() => _delivery = delivery);
      _configurePolling(delivery);
    } on TrackWarehouseDeliveryException catch (error) {
      if (!mounted) return;
      setState(() => _errorCode = error.code ?? 'UNKNOWN');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _configurePolling(TrackWarehouseDelivery delivery) {
    _pollTimer?.cancel();
    if (delivery.subscriptionStatus != 'active' &&
        delivery.subscriptionStatus != 'subscribing') {
      return;
    }
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted && !_loading && !_requesting) unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: context.brandPrimary),
        ),
      );
    }

    final delivery = _delivery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryNotice(isPending: _isPending),
        const SizedBox(height: 12),
        if (delivery == null)
          _MessageCard(
            icon: Icons.error_outline_rounded,
            color: Colors.red.shade700,
            text: _errorText(context),
            actionLabel: tr(context, ru: 'Повторить', zh: '重试'),
            onAction: () => _load(initial: true),
          )
        else ...[
          if (!delivery.configured)
            _MessageCard(
              icon: Icons.settings_outlined,
              color: Colors.orange.shade800,
              text: tr(
                context,
                ru: 'Сервис отслеживания временно не настроен.',
                zh: '物流查询服务暂未配置。',
              ),
            )
          else if (_errorCode != null || delivery.lastError != null)
            _MessageCard(
              icon: Icons.error_outline_rounded,
              color: Colors.red.shade700,
              text: _errorText(context),
              actionLabel: tr(context, ru: 'Повторить запрос', zh: '重新查询'),
              onAction: () => _request(automatic: false),
            )
          else if (delivery.isWaiting)
            _MessageCard(
              icon: Icons.sync_rounded,
              color: context.brandPrimary,
              text: tr(
                context,
                ru: 'Запрос принят. Ожидаем первое обновление от службы доставки.',
                zh: '查询已提交，正在等待快递公司的首次更新。',
              ),
            )
          else if (!delivery.hasTracking)
            _MessageCard(
              icon: Icons.route_outlined,
              color: AppColors.textSecondary,
              text: tr(
                context,
                ru: 'Информация о доставке пока не получена.',
                zh: '暂未获取到物流信息。',
              ),
            ),
          if (delivery.configured) ...[
            const SizedBox(height: 12),
            _RefreshButton(
              loading: _requesting,
              label: delivery.trace.isEmpty
                  ? tr(context, ru: 'Получить информацию', zh: '获取物流信息')
                  : tr(context, ru: 'Проверить обновления', zh: '检查更新'),
              onPressed: () => _request(automatic: false),
            ),
          ],
          if (delivery.hasTracking) ...[
            const SizedBox(height: 16),
            _DeliverySummary(delivery: delivery),
          ],
          if (delivery.isDelivered && _isPending) ...[
            const SizedBox(height: 12),
            _MessageCard(
              icon: Icons.warehouse_outlined,
              color: Colors.orange.shade800,
              text: tr(
                context,
                ru: 'Перевозчик отметил доставку, но трек ещё не отсканирован на нашем складе.',
                zh: '快递公司已标记送达，但包裹尚未在我们的仓库扫码入库。',
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            tr(context, ru: 'История доставки', zh: '物流记录'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (delivery.trace.isEmpty)
            _MessageCard(
              icon: Icons.route_outlined,
              color: AppColors.textSecondary,
              text: tr(
                context,
                ru: 'Информация о доставке пока не получена.',
                zh: '暂未获取到物流信息。',
              ),
            )
          else
            for (var index = 0; index < delivery.trace.length; index++) ...[
              _DeliveryEventCard(
                event: delivery.trace[index],
                latest: index == 0,
                color: index == 0
                    ? _stateColor(delivery, context)
                    : AppColors.textSecondary,
              ),
              if (index != delivery.trace.length - 1) const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }

  String _errorText(BuildContext context) {
    switch (_errorCode) {
      case 'NOT_CONFIGURED':
        return tr(
          context,
          ru: 'Сервис отслеживания временно не настроен.',
          zh: '物流查询服务暂未配置。',
        );
      case 'CARRIER_NOT_RECOGNIZED':
        return tr(
          context,
          ru: 'Не удалось определить службу доставки для этого трека.',
          zh: '无法识别该单号的快递公司。',
        );
      case 'NO_TRACKING_DATA':
        return tr(
          context,
          ru: 'Служба доставки пока не вернула информацию по этому треку.',
          zh: '快递公司暂未返回该单号的物流信息。',
        );
      default:
        return tr(
          context,
          ru: 'Не удалось получить статус доставки. Попробуйте ещё раз.',
          zh: '无法获取物流状态，请稍后重试。',
        );
    }
  }
}

class _DeliveryNotice extends StatelessWidget {
  final bool isPending;

  const _DeliveryNotice({required this.isPending});

  @override
  Widget build(BuildContext context) {
    final accent = context.brandPrimary;
    return _Surface(
      backgroundColor: accent.withValues(alpha: 0.07),
      borderColor: accent.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                context,
                ru: isPending
                    ? 'Это статус доставки по Китаю до нашего склада. Статус «На складе» появится только после фактического сканирования посылки.'
                    : 'Это история доставки по Китаю до нашего склада. Статус «На складе» подтверждается фактическим сканированием посылки.',
                zh: isPending
                    ? '这里显示包裹在中国境内送达我司仓库前的物流状态。只有仓库实际扫码后，状态才会变为“已入库”。'
                    : '这里显示包裹在中国境内送达我司仓库的物流记录。“已入库”状态以仓库实际扫码为准。',
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySummary extends StatelessWidget {
  final TrackWarehouseDelivery delivery;

  const _DeliverySummary({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(delivery, context);
    final carrier = delivery.carrierName ?? delivery.carrierCode ?? '—';
    final lastUpdate = delivery.lastSyncedAt == null
        ? '—'
        : DateFormat(
            'dd.MM.yyyy HH:mm',
          ).format(delivery.lastSyncedAt!.toLocal());
    return _Surface(
      child: Column(
        children: [
          _SummaryRow(
            label: tr(context, ru: 'Статус доставки', zh: '物流状态'),
            value: _stateLabel(context, delivery.externalState),
            valueColor: color,
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: tr(context, ru: 'Служба доставки', zh: '快递公司'),
            valueWidget: _TranslatedText(
              text: carrier,
              textAlign: TextAlign.right,
            ),
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: tr(context, ru: 'Последнее обновление', zh: '最后更新'),
            value: lastUpdate,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;

  const _SummaryRow({
    required this.label,
    this.value,
    this.valueColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child:
              valueWidget ??
              Text(
                value ?? '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _RefreshButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: context.brandPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 19),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DeliveryEventCard extends StatelessWidget {
  final TrackWarehouseDeliveryEvent event;
  final bool latest;
  final Color color;

  const _DeliveryEventCard({
    required this.event,
    required this.latest,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final location = event.areaName ?? event.location;
    return _Surface(
      borderColor: latest ? color.withValues(alpha: 0.25) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              latest ? Icons.local_shipping_rounded : Icons.route_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TranslatedText(text: event.context),
                if (location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  _TranslatedText(text: location!, secondary: true),
                ],
                if (event.time.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.time,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslatedText extends ConsumerWidget {
  final String text;
  final bool secondary;
  final TextAlign textAlign;

  const _TranslatedText({
    required this.text,
    this.secondary = false,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseStyle = TextStyle(
      color: secondary ? AppColors.textSecondary : AppColors.textPrimary,
      fontFamily: 'Gilroy',
      fontSize: secondary ? 12 : 13,
      height: 1.4,
      fontWeight: secondary ? FontWeight.w500 : FontWeight.w700,
    );
    if (isZh(context) || !_containsCjk(text)) {
      return Text(text, style: baseStyle, textAlign: textAlign);
    }
    final translated = ref.watch(warehouseDeliveryTranslationProvider(text));
    return translated.when(
      data: (value) => Text(value, style: baseStyle, textAlign: textAlign),
      loading: () => Text(text, style: baseStyle, textAlign: textAlign),
      error: (_, _) => Text(text, style: baseStyle, textAlign: textAlign),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  const _Surface({this.backgroundColor, this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? const Color(0xFFE9E9EE)),
      ),
      child: child,
    );
  }
}

Color _stateColor(TrackWarehouseDelivery delivery, BuildContext context) {
  if (delivery.isDelivered) return const Color(0xFF22A06B);
  if (const {'2', '4', '6', '13', '14'}.contains(delivery.externalState)) {
    return const Color(0xFFD64545);
  }
  if (delivery.externalState == '5') return const Color(0xFFE5912A);
  return context.brandPrimary;
}

String _stateLabel(BuildContext context, String? state) {
  switch (state) {
    case '0':
      return tr(context, ru: 'В пути', zh: '运输中');
    case '1':
      return tr(context, ru: 'Принято перевозчиком', zh: '已揽收');
    case '2':
      return tr(context, ru: 'Проблема при доставке', zh: '运输异常');
    case '3':
      return tr(context, ru: 'Доставлено перевозчиком', zh: '快递已送达');
    case '4':
      return tr(context, ru: 'Отказ от получения', zh: '拒收');
    case '5':
      return tr(context, ru: 'Передано курьеру', zh: '派送中');
    case '6':
      return tr(context, ru: 'Возвращается отправителю', zh: '退回中');
    case '7':
      return tr(context, ru: 'Передано другому перевозчику', zh: '转投其他快递');
    case '10':
      return tr(context, ru: 'Ожидает таможенного оформления', zh: '等待清关');
    case '11':
      return tr(context, ru: 'На таможенном оформлении', zh: '清关中');
    case '12':
      return tr(context, ru: 'Таможенное оформление завершено', zh: '清关完成');
    case '13':
      return tr(context, ru: 'Проблема на таможне', zh: '清关异常');
    case '14':
      return tr(context, ru: 'Получатель отказался', zh: '收件人拒收');
    default:
      return tr(context, ru: 'Нет данных', zh: '暂无数据');
  }
}

bool _containsCjk(String value) => RegExp(r'[\u3400-\u9FFF]').hasMatch(value);
