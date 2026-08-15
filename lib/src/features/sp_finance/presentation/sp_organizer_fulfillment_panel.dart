import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_cached_media_image.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../data/sp_organizer_fulfillment_models.dart';
import '../data/sp_organizer_provider.dart';
import 'sp_finance_ui.dart';
import 'sp_organizer_fulfillment_link_sheet.dart';

class SpOrganizerFulfillmentPanel extends ConsumerWidget {
  final int purchaseId;

  const SpOrganizerFulfillmentPanel({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(
      spOrganizerFulfillmentOverviewProvider(purchaseId),
    );
    final capabilities = ref
        .watch(spOrganizerCapabilitiesProvider)
        .asData
        ?.value;
    final canLink = capabilities?.hasFulfillmentLinkActions == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: context.brandPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, ru: 'Логистика 2A', zh: '2A 履约'),
                      style: SpFinanceUi.sectionTitleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(
                        context,
                        ru: 'Связанные операции и фактические статусы',
                        zh: '已关联操作与实际状态',
                      ),
                      style: SpFinanceUi.labelStyle,
                    ),
                  ],
                ),
              ),
              if (canLink)
                SpFinanceHeaderActionButton(
                  tooltip: tr(
                    context,
                    ru: 'Связать с операцией 2A',
                    zh: '关联2A操作',
                  ),
                  onTap: overviewAsync.asData?.value == null
                      ? null
                      : () => _openLinkSheet(
                          context,
                          ref,
                          overviewAsync.asData!.value,
                        ),
                  child: Icon(
                    Icons.add_link_rounded,
                    color: context.brandPrimary,
                    size: 20,
                  ),
                ),
              if (canLink) const SizedBox(width: 6),
              SpFinanceHeaderActionButton(
                tooltip: tr(context, ru: 'Обновить логистику', zh: '刷新履约信息'),
                onTap: () => ref.invalidate(
                  spOrganizerFulfillmentOverviewProvider(purchaseId),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: context.brandPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          overviewAsync.when(
            loading: () => const SizedBox(
              height: 112,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => _FulfillmentError(
              message:
                  '${tr(context, ru: 'Не удалось получить логистику 2A', zh: '无法获取2A履约信息')}: $error',
              onRetry: () => ref.invalidate(
                spOrganizerFulfillmentOverviewProvider(purchaseId),
              ),
            ),
            data: (overview) =>
                _FulfillmentContent(overview: overview, canLink: canLink),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinkSheet(
    BuildContext context,
    WidgetRef ref,
    SpOrganizerFulfillmentOverview overview,
  ) async {
    final capabilities = ref
        .read(spOrganizerCapabilitiesProvider)
        .asData
        ?.value;
    if (capabilities == null || !capabilities.hasFulfillmentLinkActions) return;
    final linked = await showSpOrganizerFulfillmentLinkSheet(
      context: context,
      purchaseId: purchaseId,
      overview: overview,
      capabilities: capabilities,
    );
    if (!context.mounted || linked != true) return;
    ref.invalidate(spOrganizerFulfillmentOverviewProvider(purchaseId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            context,
            ru: 'Связь добавлена. Данные 2A не изменены.',
            zh: '关联已添加。2A数据未更改。',
          ),
        ),
      ),
    );
  }
}

class _FulfillmentContent extends StatelessWidget {
  final SpOrganizerFulfillmentOverview overview;
  final bool canLink;

  const _FulfillmentContent({required this.overview, required this.canLink});

  @override
  Widget build(BuildContext context) {
    final summary = overview.summary;
    final hasHighlights =
        overview.selfBuyoutRequests.isNotEmpty ||
        overview.garageOrderItems.isNotEmpty ||
        overview.assemblies.isNotEmpty ||
        overview.invoices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 40) / 6
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.currency_yuan_rounded,
                  label: tr(context, ru: 'Самовыкуп', zh: '自主采购'),
                  value: summary.selfBuyoutRequestsCount,
                ),
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.directions_car_filled_outlined,
                  label: tr(context, ru: 'Гараж', zh: '车库'),
                  value: summary.garageOrderItemsCount,
                ),
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.qr_code_2_rounded,
                  label: tr(context, ru: 'Треки', zh: '运单'),
                  value: summary.tracksCount,
                ),
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.photo_camera_outlined,
                  label: tr(context, ru: 'Фото / запросы', zh: '照片 / 请求'),
                  value: summary.photosCount + summary.photoRequestsCount,
                ),
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.inventory_2_outlined,
                  label: tr(context, ru: 'Сборки', zh: '集货'),
                  value: summary.assembliesCount,
                ),
                _FulfillmentMetric(
                  width: tileWidth,
                  icon: Icons.receipt_long_outlined,
                  label: tr(context, ru: 'Счета 2A', zh: '2A 账单'),
                  value: summary.invoicesCount,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (!summary.hasLinks)
          _FulfillmentEmpty(itemsCount: summary.itemsCount, canLink: canLink),
        if (hasHighlights) _FulfillmentHighlights(overview: overview),
        if (hasHighlights && overview.tracks.isNotEmpty)
          const SizedBox(height: 10),
        if (overview.tracks.isNotEmpty)
          _FulfillmentTracks(tracks: overview.tracks),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: context.brandPrimary.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: context.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    ru: canLink
                        ? 'Можно только добавить связь с существующей операцией. Статусы, суммы, треки, сборки и счета не изменяются; удаление связей недоступно.'
                        : 'Только просмотр: статусы и суммы читаются из 2A. Карточка не меняет СП, треки, сборки и счета.',
                    zh: canLink
                        ? '仅可添加与现有操作的关联。状态、金额、运单、集货和账单不会更改；无法删除关联。'
                        : '仅查看：状态和金额来自2A。本卡片不会修改拼团、运单、集货或账单。',
                  ),
                  style: SpFinanceUi.labelStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FulfillmentMetric extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final int value;

  const _FulfillmentMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(11),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: context.brandPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SpFinanceUi.labelStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentHighlights extends StatelessWidget {
  final SpOrganizerFulfillmentOverview overview;

  const _FulfillmentHighlights({required this.overview});

  @override
  Widget build(BuildContext context) {
    final lines = <_FulfillmentLineData>[
      if (overview.selfBuyoutRequests.isNotEmpty)
        _FulfillmentLineData(
          icon: Icons.currency_yuan_rounded,
          title:
              '${tr(context, ru: 'Самовыкуп', zh: '自主采购')} ${overview.selfBuyoutRequests.first.requestNumber}',
          subtitle: overview.selfBuyoutRequests.first.itemTitle,
          status: overview.selfBuyoutRequests.first.status,
        ),
      if (overview.garageOrderItems.isNotEmpty)
        _FulfillmentLineData(
          icon: Icons.directions_car_filled_outlined,
          title: overview.garageOrderItems.first.partName,
          subtitle:
              '${tr(context, ru: 'Заказ Garage', zh: 'Garage 订单')} ${overview.garageOrderItems.first.orderNumber}',
          status: overview.garageOrderItems.first.status,
        ),
      if (overview.assemblies.isNotEmpty)
        _FulfillmentLineData(
          icon: Icons.inventory_2_outlined,
          title:
              '${tr(context, ru: 'Сборка', zh: '集货')} ${overview.assemblies.first.number}',
          subtitle:
              '${tr(context, ru: 'треков', zh: '运单')}: ${overview.assemblies.first.tracksCount}',
          status: overview.assemblies.first.status,
        ),
      if (overview.invoices.isNotEmpty)
        _FulfillmentLineData(
          icon: Icons.receipt_long_outlined,
          title:
              '${tr(context, ru: 'Счёт', zh: '账单')} ${overview.invoices.first.invoiceNumber}',
          subtitle: _rub(overview.invoices.first.totalCostRub),
          status: overview.invoices.first.status,
        ),
    ];

    return Container(
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0)
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.045)),
            _FulfillmentLine(data: lines[index]),
          ],
        ],
      ),
    );
  }
}

class _FulfillmentTracks extends StatelessWidget {
  final List<SpOrganizerTrackFulfillment> tracks;

  const _FulfillmentTracks({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, ru: 'Треки и фото по товарам', zh: '商品运单与照片'),
          style: SpFinanceUi.bodyStyle.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < tracks.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _FulfillmentTrackCard(track: tracks[index]),
        ],
      ],
    );
  }
}

class _FulfillmentTrackCard extends StatelessWidget {
  final SpOrganizerTrackFulfillment track;

  const _FulfillmentTrackCard({required this.track});

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final statusColor =
        SpFinanceUi.parseHexColor(track.status.color) ?? context.brandPrimary;
    return Container(
      key: ValueKey('sp-fulfillment-track-${track.trackId}'),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: tr(
              context,
              ru: 'Открыть трек ${track.trackNumber}',
              zh: '打开运单 ${track.trackNumber}',
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.go('/tracks?trackId=${track.trackId}'),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: context.brandPrimary.withValues(
                                alpha: 0.09,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 19,
                              color: context.brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tr(context, ru: 'Трек', zh: '运单')} ${track.trackNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SpFinanceUi.bodyStyle.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.itemTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SpFinanceUi.labelStyle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.brandPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _FulfillmentTrackChip(
                            label: track.status.labelFor(languageCode),
                            color: statusColor,
                          ),
                          if (track.isAutomaticGarageTrack)
                            _FulfillmentTrackChip(
                              key: ValueKey(
                                'sp-fulfillment-garage-track-${track.trackId}',
                              ),
                              label: tr(
                                context,
                                ru: 'Из Garage автоматически',
                                zh: '从Garage自动关联',
                              ),
                              icon: Icons.auto_awesome_rounded,
                              color: context.brandPrimary,
                            ),
                          _FulfillmentTrackChip(
                            label:
                                '${tr(context, ru: 'Фото', zh: '照片')}: ${track.photosCount}',
                            icon: Icons.photo_camera_outlined,
                          ),
                          if (track.photoRequestsCount > 0)
                            _FulfillmentTrackChip(
                              label:
                                  '${tr(context, ru: 'Запросы', zh: '请求')}: ${track.photoRequestsCount}',
                              icon: Icons.mark_email_unread_outlined,
                            ),
                          if (track.warehouseDelivered)
                            _FulfillmentTrackChip(
                              label: tr(
                                context,
                                ru: 'Принят складом',
                                zh: '仓库已接收',
                              ),
                              icon: Icons.warehouse_outlined,
                              color: const Color(0xFF16855A),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (track.photos.isNotEmpty) ...[
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.045)),
            SizedBox(
              height: 78,
              child: ListView.separated(
                padding: const EdgeInsets.all(9),
                scrollDirection: Axis.horizontal,
                itemCount: track.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) =>
                    _FulfillmentPhotoThumbnail(track: track, index: index),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FulfillmentTrackChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const _FulfillmentTrackChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.085),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpFinanceUi.labelStyle.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentPhotoThumbnail extends StatelessWidget {
  final SpOrganizerTrackFulfillment track;
  final int index;

  const _FulfillmentPhotoThumbnail({required this.track, required this.index});

  @override
  Widget build(BuildContext context) {
    final photo = track.photos[index];
    final item = _photoItem(photo);
    return Semantics(
      button: true,
      label: tr(
        context,
        ru: item.isVideo ? 'Открыть видеоотчёт' : 'Открыть фотоотчёт',
        zh: item.isVideo ? '打开视频报告' : '打开照片报告',
      ),
      child: Material(
        key: ValueKey('sp-fulfillment-photo-${track.trackId}-${photo.id}'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPhotoViewer(context),
          child: SizedBox(
            width: 62,
            height: 60,
            child: item.isVideo
                ? ColoredBox(
                    color: context.brandPrimary.withValues(alpha: 0.10),
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: context.brandPrimary,
                    ),
                  )
                : AppCachedMediaImage(
                    url: photo.url,
                    fit: BoxFit.cover,
                    memCacheWidth: 180,
                    memCacheHeight: 180,
                  ),
          ),
        ),
      ),
    );
  }

  void _openPhotoViewer(BuildContext context) {
    final photos = track.photos.map(_photoItem).toList(growable: false);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          item: photos[index],
          allPhotos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  PhotoItem _photoItem(SpOrganizerFulfillmentPhoto photo) {
    return PhotoItem(
      id: photo.id,
      url: photo.url,
      date: photo.createdAt,
      trackingNumber: track.trackNumber,
    );
  }
}

class _FulfillmentLineData {
  final IconData icon;
  final String title;
  final String subtitle;
  final SpOrganizerFulfillmentStatus status;

  const _FulfillmentLineData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}

class _FulfillmentLine extends StatelessWidget {
  final _FulfillmentLineData data;

  const _FulfillmentLine({required this.data});

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final color =
        SpFinanceUi.parseHexColor(data.status.color) ?? context.brandPrimary;
    return Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Icon(data.icon, color: context.brandPrimary, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpFinanceUi.bodyStyle.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpFinanceUi.labelStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 105),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.status.labelFor(languageCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpFinanceUi.labelStyle.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentEmpty extends StatelessWidget {
  final int itemsCount;
  final bool canLink;

  const _FulfillmentEmpty({required this.itemsCount, required this.canLink});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          Icon(Icons.link_off_rounded, color: context.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              itemsCount == 0
                  ? tr(
                      context,
                      ru: 'Добавьте товары, чтобы связать их с операциями 2A.',
                      zh: '添加商品后即可关联2A操作。',
                    )
                  : canLink
                  ? tr(
                      context,
                      ru: 'Нажмите «Связать», чтобы добавить существующий самовыкуп, Garage, трек, сборку или счёт 2A.',
                      zh: '点击“关联”以添加现有自主采购、Garage、运单、集货或2A账单。',
                    )
                  : tr(
                      context,
                      ru: 'Связей с операциями 2A пока нет. Существующие товары и суммы не изменены.',
                      zh: '暂未关联2A操作。现有商品和金额均未改变。',
                    ),
              style: SpFinanceUi.labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FulfillmentError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC2413A)),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: SpFinanceUi.labelStyle)),
          TextButton(
            onPressed: onRetry,
            child: Text(tr(context, ru: 'Повторить', zh: '重试')),
          ),
        ],
      ),
    );
  }
}

String _rub(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  return '$fixed ₽';
}
