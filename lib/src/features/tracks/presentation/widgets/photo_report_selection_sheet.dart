import 'package:flutter/material.dart';
import '../../../../core/utils/locale_text.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/ui/app_input_decoration.dart';
import 'track_sheet_surface.dart';
import '../../domain/photo_report_options.dart';

class PhotoReportSelectionSheet extends StatefulWidget {
  final String trackNumber;
  final Future<PhotoReportOptions> Function() loadOptions;
  final String? initialType;
  final String? initialWish;
  final String? savedPriceUsd;
  final bool allowTypeChange;

  const PhotoReportSelectionSheet({
    super.key,
    required this.trackNumber,
    required this.loadOptions,
    this.initialType,
    this.initialWish,
    this.savedPriceUsd,
    this.allowTypeChange = true,
  });

  @override
  State<PhotoReportSelectionSheet> createState() =>
      _PhotoReportSelectionSheetState();
}

class _PhotoReportSelectionSheetState extends State<PhotoReportSelectionSheet> {
  late final _wish = TextEditingController(text: widget.initialWish);
  PhotoReportOptions? _options;
  String? _type;
  bool _accepted = false;
  bool _failed = false;
  bool _wishError = false;

  @override
  void initState() {
    super.initState();
    if (widget.allowTypeChange) {
      _load();
    } else {
      _type = widget.initialType;
      _options = PhotoReportOptions(
        standard: PhotoReportOption(
          enabled: _type == 'standard',
          priceUsd: widget.savedPriceUsd ?? '0',
        ),
        custom: PhotoReportOption(
          enabled: _type == 'custom',
          priceUsd: widget.savedPriceUsd ?? '0',
        ),
      );
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final options = await widget.loadOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        final initial = widget.initialType;
        _type = initial == 'standard' || initial == 'custom'
            ? initial
            : options.standard.enabled
            ? 'standard'
            : options.custom.enabled
            ? 'custom'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  double get _price {
    if (_type == widget.initialType && widget.savedPriceUsd != null) {
      return double.tryParse(widget.savedPriceUsd!) ?? 0;
    }
    return _options?.option(_type ?? 'standard').price ?? 0;
  }

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return TrackSheetSurface(
      icon: Icons.photo_camera_rounded,
      title: tr(context, ru: 'Фотоотчёт', zh: '拍照报告'),
      subtitle: tr(
        context,
        ru: 'Трек ${widget.trackNumber}',
        zh: '包裹 ${widget.trackNumber}',
      ),
      keyboardAware: true,
      footer: options == null
          ? null
          : TrackSheetPrimaryButton(
              label: widget.initialType == null
                  ? tr(context, ru: 'Запросить фотоотчёт', zh: '申请拍照报告')
                  : tr(context, ru: 'Сохранить', zh: '保存'),
              icon: widget.initialType == null
                  ? Icons.add_a_photo_rounded
                  : Icons.check_rounded,
              onTap: _type == null || (_price > 0 && !_accepted)
                  ? null
                  : () {
                      if (_type == 'custom' && _wish.text.trim().isEmpty) {
                        setState(() => _wishError = true);
                        return;
                      }
                      Navigator.of(context).pop(
                        PhotoReportSelection(
                          _type!,
                          _type == 'custom' ? _wish.text.trim() : null,
                          _price.toStringAsFixed(2),
                        ),
                      );
                    },
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failed) ...[
            Text(
              tr(
                context,
                ru: 'Не удалось загрузить виды фотоотчётов',
                zh: '无法加载拍照报告类型',
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(tr(context, ru: 'Повторить', zh: '重试')),
            ),
          ] else if (options == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            for (final type in ['standard', 'custom'])
              if (options.option(type).enabled || type == widget.initialType)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TrackSheetOptionTile(
                    icon: type == 'standard'
                        ? Icons.photo_camera_rounded
                        : Icons.fact_check_rounded,
                    title: type == 'standard'
                        ? tr(context, ru: 'Стандартный фотоотчёт', zh: '标准拍照报告')
                        : tr(context, ru: 'Проверка по заданию', zh: '按要求检查'),
                    titleMaxLines: 2,
                    subtitle: _optionPrice(type),
                    selected: _type == type,
                    onTap: !widget.allowTypeChange
                        ? null
                        : () => setState(() {
                            _type = type;
                            _accepted = false;
                            _wishError = false;
                          }),
                  ),
                ),
            if (_type == null)
              Text(
                tr(
                  context,
                  ru: 'Фотоотчёты сейчас недоступны',
                  zh: '目前无法申请拍照报告',
                ),
              ),
            if (_type == 'standard') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.035),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, ru: 'Регламент склада', zh: '仓库标准检查内容'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final label in [
                      tr(context, ru: 'Проверка целостности', zh: '检查完整性'),
                      tr(context, ru: 'Проверка явного брака', zh: '检查明显瑕疵'),
                      tr(context, ru: 'Замер стельки', zh: '测量鞋垫长度'),
                      tr(
                        context,
                        ru: 'Фото товара с разных сторон',
                        zh: '从不同角度拍摄商品',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: context.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Gilroy',
                                  fontSize: 13.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        ru: 'Без индивидуальных пожеланий.',
                        zh: '不包含个人要求。',
                      ),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_type == 'custom') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _wish,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration:
                    appInputDecoration(
                      context,
                      labelText: tr(
                        context,
                        ru: 'Что необходимо проверить?',
                        zh: '需要检查哪些内容？',
                      ),
                      hintText: tr(
                        context,
                        ru: 'Опишите обязательные фотографии и проверки',
                        zh: '请描述所需照片及检查要求',
                      ),
                    ).copyWith(
                      errorText: _wishError
                          ? tr(
                              context,
                              ru: 'Напишите пожелания к проверке',
                              zh: '请填写检查要求',
                            )
                          : null,
                    ),
              ),
            ],
            if (_type != null && _price > 0)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                title: Text(
                  tr(
                    context,
                    ru: 'Выполненный отчёт стоит \$${_price.toStringAsFixed(2)} и оплачивается также при возврате товара. Стоимость включат в ближайший счёт на доставку.',
                    zh: '报告完成后收费 \$${_price.toStringAsFixed(2)}，退货也需支付。费用将计入下一张运输账单。',
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _optionPrice(String type) {
    final value = type == widget.initialType && widget.savedPriceUsd != null
        ? double.tryParse(widget.savedPriceUsd!) ?? 0
        : _options!.option(type).price;
    return value == 0
        ? tr(context, ru: 'Бесплатно', zh: '免费')
        : '\$${value.toStringAsFixed(2)}';
  }
}
