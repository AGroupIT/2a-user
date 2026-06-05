import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../photos/domain/photo_item.dart';
import '../../photos/presentation/photo_viewer_screen.dart';
import '../../sp_finance/presentation/sp_finance_ui.dart';
import '../data/china_marketplace_provider.dart';
import '../domain/china_marketplace_models.dart';

class ChinaMarketplacesScreen extends ConsumerStatefulWidget {
  const ChinaMarketplacesScreen({super.key});

  @override
  ConsumerState<ChinaMarketplacesScreen> createState() =>
      _ChinaMarketplacesScreenState();
}

class _ChinaMarketplacesScreenState
    extends ConsumerState<ChinaMarketplacesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _money = NumberFormat('#,##0.##', 'ru_RU');

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .search(_searchController.text);
  }

  Future<void> _pickImageSearchPhoto() async {
    FocusScope.of(context).unfocus();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: false,
        compressionQuality: 0,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = await file.xFile.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _showMarketplaceToast(
          context,
          'Не удалось прочитать изображение',
          isError: true,
        );
        return;
      }

      _searchController.clear();
      await ref
          .read(chinaMarketplacesControllerProvider.notifier)
          .searchByImage(fileName: file.name, previewBytes: bytes);
    } catch (_) {
      if (!mounted) return;
      _showMarketplaceToast(
        context,
        'Не удалось выбрать изображение',
        isError: true,
      );
    }
  }

  Future<void> _clearImageSearch() async {
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .clearImageSearch();
  }

  Future<void> _selectMarketplace(ChinaMarketplace marketplace) async {
    HapticFeedback.selectionClick();
    _searchController.clear();
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .selectMarketplace(marketplace);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chinaMarketplacesControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref
              .read(chinaMarketplacesControllerProvider.notifier)
              .refreshCurrentSearch(),
          color: context.brandPrimary,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, bottomPad + 16),
            children: [
              _MarketplacesHero(state: state),
              const SizedBox(height: 14),
              _MarketplaceSelector(
                selected: state.marketplace,
                onChanged: _selectMarketplace,
              ),
              const SizedBox(height: 12),
              _SearchPanel(
                controller: _searchController,
                state: state,
                onSearch: _search,
                onPickImage: _pickImageSearchPhoto,
                onClearImage: _clearImageSearch,
              ),
              const SizedBox(height: 12),
              _CategoryAndFilterBar(state: state),
              const SizedBox(height: 18),
              _ResultsHeader(
                state: state,
                money: _money,
                onClear: state.query.isEmpty && !state.isImageSearchMode
                    ? null
                    : () {
                        _searchController.clear();
                        ref
                            .read(chinaMarketplacesControllerProvider.notifier)
                            .search('');
                      },
              ),
              const SizedBox(height: 10),
              if (state.isSearching)
                const _ProductsLoadingGrid()
              else if (state.products.isEmpty)
                const _EmptySearchState()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useGrid = constraints.maxWidth >= 560;
                    if (useGrid) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.62,
                            ),
                        itemCount: state.products.length,
                        itemBuilder: (context, index) => _ProductCard(
                          product: state.products[index],
                          money: _money,
                          onTap: () => context.push(
                            '/marketplaces/product/${state.products[index].id}',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final product in state.products) ...[
                          _ProductCard(
                            product: product,
                            money: _money,
                            onTap: () => context.push(
                              '/marketplaces/product/${product.id}',
                            ),
                          ),
                          if (product != state.products.last)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 18),
              _CartPreview(state: state, money: _money),
              const SizedBox(height: 10),
              const _ManagerOnlyNotice(),
            ],
          ),
        ),
        ScrollToTopButton(controller: _scrollController),
      ],
    );
  }
}

void _showMarketplaceToast(
  BuildContext context,
  String message, {
  bool isError = false,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final hasAction = actionLabel != null && onAction != null;
  if (!hasAction) {
    AppToast.show(context, message, isError: isError, icon: icon);
    return;
  }

  AppToast.showContent(
    context,
    isError: isError,
    backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
    duration: const Duration(seconds: 3),
    content: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ??
                (isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            AppToast.hide();
            onAction();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle: const TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

class _MarketplacesHero extends StatelessWidget {
  final ChinaMarketplacesState state;

  const _MarketplacesHero({required this.state});

  @override
  Widget build(BuildContext context) {
    return SpAnimatedHeroSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.cart_badge_plus,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Китайские маркетплейсы',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontSize: 25,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ищите товары, собирайте корзину, а выкуп подтвердит менеджер 2A.',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontSize: 13.5,
                        height: 1.22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const SpHeroChip(icon: Icons.storefront_rounded, label: '1688'),
              const SpHeroChip(
                icon: Icons.shopping_bag_rounded,
                label: 'Taobao',
              ),
              const SpHeroChip(
                icon: Icons.local_offer_rounded,
                label: 'Pinduoduo',
              ),
              SpHeroChip(
                icon: Icons.shopping_cart_checkout_rounded,
                label: '${state.cartQuantity} в корзине',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagerOnlyNotice extends StatelessWidget {
  const _ManagerOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: context.brandPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Как оформить выкуп',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Добавьте товары в корзину-заявку. Менеджер проверит наличие, варианты, доставку по Китаю и согласует итог перед выкупом.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12.5,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSelector extends StatelessWidget {
  final ChinaMarketplace selected;
  final ValueChanged<ChinaMarketplace> onChanged;

  const _MarketplaceSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final marketplace in ChinaMarketplace.values) ...[
          Expanded(
            child: _MarketplaceTab(
              marketplace: marketplace,
              isSelected: marketplace == selected,
              onTap: () => onChanged(marketplace),
            ),
          ),
          if (marketplace != ChinaMarketplace.values.last)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MarketplaceTab extends StatelessWidget {
  final ChinaMarketplace marketplace;
  final bool isSelected;
  final VoidCallback onTap;

  const _MarketplaceTab({
    required this.marketplace,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? context.brandGradient : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.035),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? context.brandPrimary.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                marketplace.icon,
                color: isSelected ? Colors.white : context.brandPrimary,
                size: 22,
              ),
              const SizedBox(height: 7),
              Text(
                marketplace.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                marketplace.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.82)
                      : AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final ChinaMarketplacesState state;
  final VoidCallback onSearch;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  const _SearchPanel({
    required this.controller,
    required this.state,
    required this.onSearch,
    required this.onPickImage,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppOutlinedInputFrame(
                  height: 52,
                  radius: 18,
                  focusedBorderWidth: 1.25,
                  fillColor: const Color(0xFFF8FAFC),
                  builder: (context, focusNode) => TextField(
                    focusNode: focusNode,
                    controller: controller,
                    cursorColor: context.brandPrimary,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Поиск на ${state.marketplace.displayName}',
                      hintStyle: const TextStyle(
                        color: Color(0xFFADB4C0),
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: focusNode.hasFocus
                          ? null
                          : Icon(
                              CupertinoIcons.search,
                              color: context.brandPrimary,
                              size: 21,
                            ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 46,
                        minHeight: 46,
                      ),
                      contentPadding: EdgeInsets.fromLTRB(
                        focusNode.hasFocus ? 16 : 0,
                        16,
                        14,
                        16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SearchSquareButton(
                icon: CupertinoIcons.camera_fill,
                tooltip: 'Поиск по фото',
                onPressed: onPickImage,
                filled: false,
              ),
              const SizedBox(width: 8),
              _SearchSquareButton(
                icon: Icons.arrow_forward_rounded,
                tooltip: 'Найти',
                onPressed: onSearch,
                filled: true,
              ),
            ],
          ),
          if (state.isImageSearchMode &&
              state.imageSearchPreviewBytes != null) ...[
            const SizedBox(height: 10),
            _ImageSearchPreview(state: state, onClear: onClearImage),
          ],
        ],
      ),
    );
  }
}

class _SearchSquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  const _SearchSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: filled ? context.brandGradient : null,
          color: filled ? null : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: filled
              ? null
              : Border.all(color: context.brandPrimary.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
              color: context.brandPrimary.withValues(
                alpha: filled ? 0.16 : 0.08,
              ),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: filled ? Colors.white : context.brandPrimary,
          tooltip: tooltip,
        ),
      ),
    );
  }
}

class _ImageSearchPreview extends StatelessWidget {
  final ChinaMarketplacesState state;
  final VoidCallback onClear;

  const _ImageSearchPreview({required this.state, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final message = state.marketplace == ChinaMarketplace.pinduoduo
        ? 'Для Pinduoduo backend будет искать через распознавание фото и китайские ключевые слова.'
        : 'Для ${state.marketplace.displayName} backend сможет отправить фото в image-search API площадки.';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              state.imageSearchPreviewBytes!,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                width: 54,
                height: 54,
                color: context.brandPrimary.withValues(alpha: 0.10),
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: context.brandPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.imageSearchFileName ?? 'Поиск по фото',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Очистить фото',
          ),
        ],
      ),
    );
  }
}

class _CategoryAndFilterBar extends ConsumerWidget {
  static const _allCategoriesValue = '__all_categories__';

  final ChinaMarketplacesState state;

  const _CategoryAndFilterBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(
      chinaMarketplaceCategoriesProvider(state.marketplace),
    );
    final categoryActive = state.selectedCategory?.isNotEmpty == true;
    final filterActive = state.filter != MarketplaceCatalogFilter.all;
    final sortActive = state.sort != MarketplaceSortOption.popular;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _MarketplaceControlButton(
              icon: Icons.grid_view_rounded,
              title: 'Категории',
              value: categoryActive ? state.selectedCategory! : 'Все',
              active: categoryActive,
              onTap: () => _showCategorySheet(context, ref, categories),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MarketplaceControlButton(
              icon: Icons.tune_rounded,
              title: 'Фильтр',
              value: filterActive ? state.filter.label : 'Все',
              active: filterActive,
              onTap: () => _showFilterSheet(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MarketplaceControlButton(
              icon: Icons.swap_vert_rounded,
              title: 'Сорт',
              value: state.sort.label,
              active: sortActive,
              onTap: () => _showSortSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategorySheet(
    BuildContext context,
    WidgetRef ref,
    List<String> categories,
  ) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    final selected = await showBlurredModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => _MarketplaceChoiceSheet<String>(
        icon: Icons.grid_view_rounded,
        title: 'Категории',
        subtitle: 'Выберите раздел товаров на ${state.marketplace.displayName}',
        selected: state.selectedCategory ?? _allCategoriesValue,
        options: [
          const _MarketplaceSheetOption(
            value: _allCategoriesValue,
            icon: Icons.auto_awesome_rounded,
            title: 'Все категории',
            subtitle: 'Показать товары из всех разделов',
          ),
          for (final category in categories)
            _MarketplaceSheetOption(
              value: category,
              icon: Icons.category_rounded,
              title: category,
              subtitle: 'Товары раздела ${state.marketplace.displayName}',
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;
    final category = selected == _allCategoriesValue ? null : selected;
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .selectCategory(category);
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    final selected =
        await showBlurredModalBottomSheet<MarketplaceCatalogFilter>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.22),
          builder: (_) => _MarketplaceChoiceSheet<MarketplaceCatalogFilter>(
            icon: Icons.tune_rounded,
            title: 'Фильтр',
            subtitle: 'Быстро сузьте выдачу по важным условиям',
            selected: state.filter,
            options: [
              for (final filter in MarketplaceCatalogFilter.values)
                _MarketplaceSheetOption(
                  value: filter,
                  icon: filter.icon,
                  title: filter.label,
                  subtitle: _filterDescription(filter),
                ),
            ],
          ),
        );

    if (selected == null || !context.mounted) return;
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .selectFilter(selected);
  }

  Future<void> _showSortSheet(BuildContext context, WidgetRef ref) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    final selected = await showBlurredModalBottomSheet<MarketplaceSortOption>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => _MarketplaceChoiceSheet<MarketplaceSortOption>(
        icon: Icons.swap_vert_rounded,
        title: 'Сортировка',
        subtitle: 'Выберите порядок отображения товаров',
        selected: state.sort,
        options: [
          for (final sort in MarketplaceSortOption.values)
            _MarketplaceSheetOption(
              value: sort,
              icon: sort.icon,
              title: sort.label,
              subtitle: _sortDescription(sort),
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;
    await ref
        .read(chinaMarketplacesControllerProvider.notifier)
        .selectSort(selected);
  }

  String _filterDescription(MarketplaceCatalogFilter filter) {
    switch (filter) {
      case MarketplaceCatalogFilter.all:
        return 'Без дополнительных ограничений';
      case MarketplaceCatalogFilter.topRated:
        return 'Товары с высоким рейтингом товара и продавца';
      case MarketplaceCatalogFilter.manyReviews:
        return 'Позиции, по которым уже есть много отзывов';
      case MarketplaceCatalogFilter.freeChinaDelivery:
        return 'Товары с бесплатной доставкой по Китаю';
      case MarketplaceCatalogFilter.smallMinimum:
        return 'Товары с небольшим минимальным количеством';
    }
  }

  String _sortDescription(MarketplaceSortOption sort) {
    switch (sort) {
      case MarketplaceSortOption.popular:
        return 'По умолчанию: популярность, отзывы и рекомендации';
      case MarketplaceSortOption.priceAsc:
        return 'Сначала товары с меньшей ценой';
      case MarketplaceSortOption.priceDesc:
        return 'Сначала товары с большей ценой';
      case MarketplaceSortOption.rating:
        return 'Сначала товары с высоким рейтингом';
    }
  }
}

class _MarketplaceControlButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool active;
  final VoidCallback onTap;

  const _MarketplaceControlButton({
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.textPrimary;
    final muted = active
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? context.brandGradient : null,
            color: active ? null : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.045),
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? context.brandPrimary.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                spreadRadius: -9,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: active ? Colors.white : context.brandPrimary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontFamily: 'Gilroy',
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: muted,
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

class _MarketplaceSheetOption<T> {
  final T value;
  final IconData icon;
  final String title;
  final String subtitle;

  const _MarketplaceSheetOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _MarketplaceChoiceSheet<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final T selected;
  final List<_MarketplaceSheetOption<T>> options;

  const _MarketplaceChoiceSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 58,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D8DD),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SpAnimatedHeroSurface(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 27),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy',
                              fontSize: 23,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy',
                              fontSize: 12.5,
                              height: 1.22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 18),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _MarketplaceSheetOptionTile<T>(
                    option: option,
                    selected: option.value == selected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceSheetOptionTile<T> extends StatelessWidget {
  final _MarketplaceSheetOption<T> option;
  final bool selected;

  const _MarketplaceSheetOptionTile({
    required this.option,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(option.value);
        },
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? context.brandPrimary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? context.brandPrimary.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.045),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: selected ? context.brandGradient : null,
                  color: selected
                      ? null
                      : context.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : context.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 15.5,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.2,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: selected ? context.brandGradient : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  size: selected ? 20 : 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final ChinaMarketplacesState state;
  final NumberFormat money;
  final VoidCallback? onClear;

  const _ResultsHeader({
    required this.state,
    required this.money,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final title = state.isImageSearchMode
        ? 'Похожие товары'
        : state.query.isEmpty
        ? 'Рекомендации'
        : 'Результаты поиска';
    final subtitleParts = [
      state.marketplace.displayName,
      '${state.products.length} позиций',
      state.sort.label.toLowerCase(),
    ];
    if (state.selectedCategory != null) {
      subtitleParts.add(state.selectedCategory!);
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 20,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' · '),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            child: Text(
              'Сбросить',
              style: TextStyle(
                color: context.brandPrimary,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final MarketplaceProduct product;
  final NumberFormat money;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: SpFinanceUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductPhoto(
                imageUrl: product.mainImageUrl,
                fallbackIcon: product.marketplace.icon,
                aspectRatio: 1.18,
                overlay: Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Row(
                    children: [
                      _PhotoOverlayPill(
                        icon: product.marketplace.icon,
                        label: product.marketplace.displayName,
                      ),
                      const Spacer(),
                      _PhotoOverlayPill(
                        icon: Icons.star_rounded,
                        label:
                            '${product.rating.toStringAsFixed(1)} · ${money.format(product.reviewCount)}',
                      ),
                    ],
                  ),
                ),
              ),
              if (product.imageUrls.length > 1) ...[
                const SizedBox(height: 8),
                _ProductMiniThumbStrip(product: product),
              ],
              const SizedBox(height: 11),
              Row(
                children: [
                  _SmallBadge(label: product.category, isAccent: true),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                product.titleRu,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 17,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                product.originalTitle,
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
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Цена',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '¥${money.format(product.priceCny)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SellerRatingBadge(
                    rating: product.sellerRating,
                    reviews: product.sellerReviewCount,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    icon: Icons.inventory_2_rounded,
                    label: 'от ${product.minOrderQuantity} шт.',
                  ),
                  _MetaChip(
                    icon: Icons.local_shipping_rounded,
                    label:
                        'Китай ¥${money.format(product.domesticDeliveryCny)}',
                  ),
                  _MetaChip(
                    icon: Icons.trending_up_rounded,
                    label: '${money.format(product.monthlySales)} продаж',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(chinaMarketplacesControllerProvider.notifier)
                        .addToCart(product, quantity: product.minOrderQuantity);
                    HapticFeedback.lightImpact();
                    _showMarketplaceToast(
                      context,
                      'Товар добавлен в корзину',
                      icon: Icons.add_shopping_cart_rounded,
                      actionLabel: 'Открыть',
                      onAction: () => context.go('/marketplaces/cart'),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('В корзину'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductMiniThumbStrip extends StatelessWidget {
  final MarketplaceProduct product;

  const _ProductMiniThumbStrip({required this.product});

  @override
  Widget build(BuildContext context) {
    final photos = product.imageUrls.take(3).toList(growable: false);
    return Row(
      children: [
        for (var index = 0; index < photos.length; index++) ...[
          Expanded(
            child: _ProductPhoto(
              imageUrl: photos[index],
              fallbackIcon: product.marketplace.icon,
              aspectRatio: 1.72,
              showScrim: false,
            ),
          ),
          if (index != photos.length - 1) const SizedBox(width: 6),
        ],
        if (product.imageUrls.length > photos.length) ...[
          const SizedBox(width: 6),
          Container(
            width: 46,
            height: 28,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '+${product.imageUrls.length - photos.length}',
                style: TextStyle(
                  color: context.brandPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  final String imageUrl;
  final IconData fallbackIcon;
  final double aspectRatio;
  final Widget? overlay;
  final bool showScrim;

  const _ProductPhoto({
    required this.imageUrl,
    required this.fallbackIcon,
    this.aspectRatio = 1,
    this.overlay,
    this.showScrim = true,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    _ProductPhotoFallback(icon: fallbackIcon),
                errorWidget: (_, _, _) =>
                    _ProductPhotoFallback(icon: fallbackIcon),
              )
            else
              _ProductPhotoFallback(icon: fallbackIcon),
            if (showScrim)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.56),
                      ],
                      stops: const [0.55, 1],
                    ),
                  ),
                ),
              ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

class _ProductPhotoFallback extends StatelessWidget {
  final IconData icon;

  const _ProductPhotoFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.brandPrimary.withValues(alpha: 0.16),
            context.brandSecondary.withValues(alpha: 0.24),
          ],
        ),
      ),
      child: Center(child: Icon(icon, color: context.brandPrimary, size: 40)),
    );
  }
}

class _PhotoOverlayPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PhotoOverlayPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerRatingBadge extends StatelessWidget {
  final double rating;
  final int reviews;
  final bool compact;

  const _SellerRatingBadge({
    required this.rating,
    required this.reviews,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_rounded, color: context.brandPrimary, size: 14),
          const SizedBox(width: 5),
          Text(
            compact
                ? 'Продавец ${rating.toStringAsFixed(1)}'
                : 'Продавец ${rating.toStringAsFixed(1)} · ${_compactCount(reviews)}',
            style: TextStyle(
              color: context.brandPrimary,
              fontFamily: 'Gilroy',
              fontSize: compact ? 10.5 : 12,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    final text = compact >= 10
        ? compact.toStringAsFixed(0)
        : compact.toStringAsFixed(1);
    return '${text.replaceAll('.', ',')} тыс.';
  }
  return '$value';
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isAccent;

  const _SmallBadge({required this.label, this.icon, this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? context.brandPrimary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAccent ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Gilroy',
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.brandPrimary, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPreview extends StatelessWidget {
  final ChinaMarketplacesState state;
  final NumberFormat money;

  const _CartPreview({required this.state, required this.money});

  @override
  Widget build(BuildContext context) {
    if (state.cart.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => context.go('/marketplaces/cart'),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: SpFinanceUi.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: context.brandGradient,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Корзина',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${state.cartQuantity} шт. · ¥${money.format(state.cartBaseCny)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: context.brandPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _TotalCell({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class ChinaMarketplaceCartScreen extends ConsumerWidget {
  const ChinaMarketplaceCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chinaMarketplacesControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final money = NumberFormat('#,##0.##', 'ru_RU');

    if (state.cart.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, bottomPad + 16),
        children: [
          const SpPageHeader(title: 'Корзина', fallbackRoute: '/marketplaces'),
          const SizedBox(height: 16),
          _DetailStateCard(
            icon: CupertinoIcons.cart,
            title: 'Корзина пустая',
            message:
                'Вернитесь в каталог, выберите товары и добавьте их в корзину.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => context.go('/marketplaces'),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Перейти в каталог'),
              style: FilledButton.styleFrom(
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topPad * 0.7 + 16,
            16,
            bottomPad + 104,
          ),
          children: [
            SpPageHeader(
              title: 'Корзина',
              fallbackRoute: '/marketplaces',
              trailing: TextButton(
                onPressed: () => ref
                    .read(chinaMarketplacesControllerProvider.notifier)
                    .clearCart(),
                child: Text(
                  'Очистить',
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SpAnimatedHeroSurface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Корзина',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${state.cartQuantity} шт. · ${state.cart.length} позиций · ¥${money.format(state.cartBaseCny)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontSize: 12.5,
                            height: 1.22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final item in state.cart) ...[
              _CartDetailItemCard(item: item, money: money),
              if (item != state.cart.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: AppLayout.bottomBarObstruction(context) + 10,
          child: _CartSubmitBar(state: state, money: money),
        ),
      ],
    );
  }
}

class _CartDetailItemCard extends ConsumerWidget {
  final MarketplaceCartItem item;
  final NumberFormat money;

  const _CartDetailItemCard({required this.item, required this.money});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chinaMarketplacesControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: _ProductPhoto(
              imageUrl: item.product.mainImageUrl,
              fallbackIcon: item.product.marketplace.icon,
              aspectRatio: 1,
              showScrim: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SmallBadge(label: item.product.marketplace.displayName),
                    const SizedBox(width: 6),
                    _SmallBadge(
                      label: item.sku?.nameRu ?? 'Без вариации',
                      isAccent: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.product.titleRu,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 15.5,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¥${money.format(item.unitCny)} за шт. · итого ¥${money.format(item.totalCny)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: item.quantity <= item.product.minOrderQuantity
                          ? null
                          : () => controller.changeCartQuantity(
                              item.key,
                              item.quantity - 1,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () => controller.changeCartQuantity(
                        item.key,
                        item.quantity + 1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => controller.removeFromCart(item.key),
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: const Color(0xFFE53935),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSubmitBar extends StatelessWidget {
  final ChinaMarketplacesState state;
  final NumberFormat money;

  const _CartSubmitBar({required this.state, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Итого по товарам',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '¥${money.format(state.cartBaseCny)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _showMarketplaceToast(
                context,
                'Отправка заявки будет подключена после backend API.',
                icon: Icons.info_outline_rounded,
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Отправить'),
              style: FilledButton.styleFrom(
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChinaMarketplaceProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ChinaMarketplaceProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(chinaMarketplaceProductProvider(productId));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return productAsync.when(
      loading: () => ListView(
        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, bottomPad + 16),
        children: const [
          SpPageHeader(
            title: 'Карточка товара',
            fallbackRoute: '/marketplaces',
          ),
          SizedBox(height: 18),
          _ProductsLoadingGrid(),
        ],
      ),
      error: (_, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, bottomPad + 16),
        children: const [
          SpPageHeader(
            title: 'Карточка товара',
            fallbackRoute: '/marketplaces',
          ),
          SizedBox(height: 18),
          _DetailStateCard(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось открыть товар',
            message:
                'Попробуйте вернуться в каталог и открыть карточку ещё раз.',
          ),
        ],
      ),
      data: (product) {
        if (product == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 16,
            ),
            children: const [
              SpPageHeader(
                title: 'Карточка товара',
                fallbackRoute: '/marketplaces',
              ),
              SizedBox(height: 18),
              _DetailStateCard(
                icon: Icons.search_off_rounded,
                title: 'Товар не найден',
                message:
                    'Возможно, карточка была обновлена. Вернитесь в каталог и выберите товар заново.',
              ),
            ],
          );
        }
        return _ProductDetailPage(product: product);
      },
    );
  }
}

class _ProductDetailPage extends ConsumerStatefulWidget {
  final MarketplaceProduct product;

  const _ProductDetailPage({required this.product});

  @override
  ConsumerState<_ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<_ProductDetailPage> {
  late int _quantity;
  MarketplaceSkuOption? _sku;
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();
  final _money = NumberFormat('#,##0.##', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _quantity = widget.product.minOrderQuantity;
    _sku = widget.product.skuOptions.isEmpty
        ? null
        : widget.product.skuOptions.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final unitCny = widget.product.priceCny + (_sku?.priceDeltaCny ?? 0);
    final totalCny = unitCny * _quantity;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 86,
            ),
            children: [
              const SpPageHeader(
                title: 'Карточка товара',
                fallbackRoute: '/marketplaces',
              ),
              const SizedBox(height: 14),
              _ProductGallery(product: widget.product, money: _money),
              const SizedBox(height: 12),
              _ProductIntroCard(product: widget.product, money: _money),
              const SizedBox(height: 12),
              _ProductTrustCard(product: widget.product, money: _money),
              const SizedBox(height: 12),
              _SheetSection(
                title: 'Вариация и количество',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.product.skuOptions.isEmpty)
                      const Text(
                        'У этой карточки пока нет опций в mock-данных. После подключения API здесь будут цвета, размеры и комплектации.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sku in widget.product.skuOptions)
                            ChoiceChip(
                              label: Text(sku.nameRu),
                              selected: _sku?.id == sku.id,
                              showCheckmark: false,
                              selectedColor: context.brandPrimary,
                              backgroundColor: const Color(0xFFF8FAFC),
                              labelStyle: TextStyle(
                                color: _sku?.id == sku.id
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w800,
                              ),
                              onSelected: (_) => setState(() => _sku = sku),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Количество',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _QtyButton(
                          icon: Icons.remove_rounded,
                          onTap: _quantity <= widget.product.minOrderQuantity
                              ? null
                              : () => setState(() => _quantity -= 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _QtyButton(
                          icon: Icons.add_rounded,
                          onTap: () => setState(() => _quantity += 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ProductAttributesSection(attributes: widget.product.attributes),
              const SizedBox(height: 12),
              _ProductDescriptionSection(product: widget.product),
              const SizedBox(height: 12),
              _ProductReviewsSection(product: widget.product, money: _money),
              const SizedBox(height: 12),
              _SheetSection(
                title: 'Комментарий менеджеру',
                child: AppOutlinedInputFrame(
                  radius: 18,
                  fillColor: const Color(0xFFF8FAFC),
                  builder: (context, focusNode) => TextField(
                    focusNode: focusNode,
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                      hintText:
                          'Например: нужен размер 39, цвет как на втором фото, проверить упаковку',
                      hintStyle: TextStyle(
                        color: Color(0xFFADB4C0),
                        fontFamily: 'Gilroy',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SheetSection(
                title: 'Предварительный расчёт',
                child: Row(
                  children: [
                    Expanded(
                      child: _TotalCell(
                        label: 'Цена за шт.',
                        value: '¥${_money.format(unitCny)}',
                      ),
                    ),
                    Expanded(
                      child: _TotalCell(
                        label: 'Итого',
                        value: '¥${_money.format(totalCny)}',
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    _openMarketplaceSource(context, widget.product.externalUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Открыть исходную карточку площадки'),
                style: TextButton.styleFrom(
                  foregroundColor: context.brandPrimary,
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: AppLayout.bottomBarObstruction(context) + 10,
            child: _DetailAddToCartBar(
              totalCny: totalCny,
              money: _money,
              onAdd: () {
                ref
                    .read(chinaMarketplacesControllerProvider.notifier)
                    .addToCart(
                      widget.product,
                      sku: _sku,
                      quantity: _quantity,
                      note: _noteController.text,
                    );
                HapticFeedback.lightImpact();
                _showMarketplaceToast(
                  context,
                  'Товар добавлен в корзину',
                  icon: Icons.add_shopping_cart_rounded,
                  actionLabel: 'Открыть',
                  onAction: () => context.go('/marketplaces/cart'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGallery extends StatefulWidget {
  final MarketplaceProduct product;
  final NumberFormat money;

  const _ProductGallery({required this.product, required this.money});

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen(int index) {
    final photos = widget.product.imageUrls;
    if (photos.isEmpty) return;

    final items = photos
        .map(
          (url) => PhotoItem(
            url: url,
            date: DateTime.now(),
            trackingNumber: widget.product.externalId,
          ),
        )
        .toList(growable: false);
    final safeIndex = index.clamp(0, items.length - 1);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          item: items[safeIndex],
          allPhotos: items,
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.product.imageUrls;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isEmpty)
            _ProductPhoto(
              imageUrl: '',
              fallbackIcon: widget.product.marketplace.icon,
              aspectRatio: 1,
            )
          else
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                controller: _pageController,
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() => _selectedIndex = index);
                },
                itemBuilder: (context, index) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openFullscreen(index),
                    child: _ProductPhoto(
                      imageUrl: photos[index],
                      fallbackIcon: widget.product.marketplace.icon,
                      aspectRatio: 1,
                      overlay: Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            _PhotoOverlayPill(
                              icon: widget.product.marketplace.icon,
                              label: widget.product.marketplace.displayName,
                            ),
                            const Spacer(),
                            _PhotoOverlayPill(
                              icon: Icons.star_rounded,
                              label:
                                  '${widget.product.rating.toStringAsFixed(1)} · ${widget.money.format(widget.product.reviewCount)} отзывов',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (photos.length > 1) ...[
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < photos.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: _selectedIndex == index ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _selectedIndex == index
                            ? context.brandPrimary
                            : context.brandPrimary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 64,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? context.brandPrimary
                              : Colors.black.withValues(alpha: 0.05),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: _ProductPhoto(
                        imageUrl: photos[index],
                        fallbackIcon: widget.product.marketplace.icon,
                        aspectRatio: 1,
                        showScrim: false,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductIntroCard extends StatelessWidget {
  final MarketplaceProduct product;
  final NumberFormat money;

  const _ProductIntroCard({required this.product, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallBadge(label: product.category, isAccent: true),
              _SmallBadge(
                label: product.translationStatus.label,
                icon: Icons.translate_rounded,
              ),
              _SmallBadge(label: product.marketplace.displayName),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.titleRu,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 22,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            product.originalTitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TotalCell(
                  label: 'Цена по карточке',
                  value: '¥${money.format(product.priceCny)}',
                ),
              ),
              _SellerRatingBadge(
                rating: product.sellerRating,
                reviews: product.sellerReviewCount,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MetaChip(
                icon: Icons.inventory_2_rounded,
                label: 'минимум ${product.minOrderQuantity} шт.',
              ),
              _MetaChip(
                icon: Icons.local_shipping_rounded,
                label: 'Китай ¥${money.format(product.domesticDeliveryCny)}',
              ),
              _MetaChip(
                icon: Icons.trending_up_rounded,
                label: '${money.format(product.monthlySales)} продаж',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductTrustCard extends StatelessWidget {
  final MarketplaceProduct product;
  final NumberFormat money;

  const _ProductTrustCard({required this.product, required this.money});

  @override
  Widget build(BuildContext context) {
    return _SheetSection(
      title: 'Отзывы и продавец',
      child: Row(
        children: [
          Expanded(
            child: _InfoMetricTile(
              icon: Icons.star_rounded,
              label: 'Рейтинг товара',
              value: product.rating.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoMetricTile(
              icon: Icons.reviews_rounded,
              label: 'Отзывы',
              value: money.format(product.reviewCount),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoMetricTile(
              icon: Icons.storefront_rounded,
              label: 'Продавец',
              value: product.sellerRating.toStringAsFixed(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.brandPrimary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 10.5,
              height: 1.08,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductAttributesSection extends StatelessWidget {
  final List<MarketplaceProductAttribute> attributes;

  const _ProductAttributesSection({required this.attributes});

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) {
      return const _SheetSection(
        title: 'Характеристики',
        child: Text(
          'Характеристики появятся после загрузки детальной карточки из API.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _SheetSection(
      title: 'Характеристики',
      child: Column(
        children: [
          for (var i = 0; i < attributes.length; i++) ...[
            _AttributeRow(attribute: attributes[i]),
            if (i != attributes.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  final MarketplaceProductAttribute attribute;

  const _AttributeRow({required this.attribute});

  @override
  Widget build(BuildContext context) {
    final original = [
      attribute.originalName,
      attribute.originalValue,
    ].where((item) => item.trim().isNotEmpty).join(': ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              attribute.name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  attribute.value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (original.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    original,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
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

class _ProductDescriptionSection extends StatelessWidget {
  final MarketplaceProduct product;

  const _ProductDescriptionSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return _SheetSection(
      title: 'Описание',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.descriptionRu,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: SpFinanceUi.softDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Оригинальное название для менеджера',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.originalTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductReviewsSection extends StatelessWidget {
  final MarketplaceProduct product;
  final NumberFormat money;

  const _ProductReviewsSection({required this.product, required this.money});

  @override
  Widget build(BuildContext context) {
    if (product.reviews.isEmpty) {
      return const _SheetSection(
        title: 'Отзывы покупателей',
        child: Text(
          'Отзывы будут загружаться из карточки площадки после подключения API.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _SheetSection(
      title: 'Отзывы покупателей',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${money.format(product.reviewCount)} отзывов в карточке · показаны последние примеры',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < product.reviews.length; i++) ...[
            _ReviewTile(review: product.reviews[i]),
            if (i != product.reviews.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final MarketplaceProductReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.softDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: context.brandPrimary, size: 16),
              const SizedBox(width: 5),
              Text(
                review.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                review.dateLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailAddToCartBar extends StatelessWidget {
  final double totalCny;
  final NumberFormat money;
  final VoidCallback onAdd;

  const _DetailAddToCartBar({
    required this.totalCny,
    required this.money,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: SpFinanceUi.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Итого по позиции',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '¥${money.format(totalCny)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('В корзину'),
              style: FilledButton.styleFrom(
                backgroundColor: context.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DetailStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: context.brandPrimary, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openMarketplaceSource(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    _showMarketplaceToast(context, 'Не удалось открыть ссылку', isError: true);
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SpFinanceUi.cardDecoration(color: const Color(0xFFFFFFFF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: onTap == null
            ? const Color(0xFFE5E7EB)
            : context.brandPrimary.withValues(alpha: 0.12),
        foregroundColor: onTap == null
            ? AppColors.textSecondary
            : context.brandPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ProductsLoadingGrid extends StatelessWidget {
  const _ProductsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 166,
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          decoration: SpFinanceUi.cardDecoration(),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: context.brandPrimary, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Ничего не нашли',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Попробуйте другой запрос или выберите другую площадку.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
