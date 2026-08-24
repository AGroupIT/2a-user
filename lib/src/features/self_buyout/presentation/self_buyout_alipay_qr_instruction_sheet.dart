import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/locale_text.dart';
import 'self_buyout_ui.dart';

const _instructionAsset =
    'assets/images/self_buyout_alipay_receive_qr_instruction.png';

class SelfBuyoutAlipayQrInstructionSheet extends StatefulWidget {
  final bool? initialAlipayTopUpExperienced;

  const SelfBuyoutAlipayQrInstructionSheet({
    super.key,
    this.initialAlipayTopUpExperienced,
  });

  @override
  State<SelfBuyoutAlipayQrInstructionSheet> createState() =>
      _SelfBuyoutAlipayQrInstructionSheetState();
}

class _SelfBuyoutAlipayQrInstructionSheetState
    extends State<SelfBuyoutAlipayQrInstructionSheet> {
  final _controller = PageController();
  int _page = 0;
  bool? _alipayTopUpExperienced;

  @override
  void initState() {
    super.initState();
    _alipayTopUpExperienced = widget.initialAlipayTopUpExperienced;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final steps = [
      tr(
        context,
        ru: 'На главном экране Alipay нажмите Pay/Receive',
        zh: '在支付宝首页点击“收付款”',
      ),
      tr(
        context,
        ru: 'В разделе Pay / Receive выберите Receive',
        zh: '在“收付款”页面选择“收款”',
      ),
      tr(
        context,
        ru: 'Нажмите Save image и загрузите сохранённый QR в заявку',
        zh: '点击“保存图片”，然后将二维码上传到申请中',
      ),
    ];

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SelfBuyoutGradientHeader(
                icon: Icons.qr_code_2_rounded,
                title: tr(
                  context,
                  ru: 'QR-код для получения юаней',
                  zh: '人民币收款二维码',
                ),
                subtitle: tr(
                  context,
                  ru: 'Где найти и сохранить его в Alipay',
                  zh: '如何在支付宝中找到并保存',
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExperienceQuestion(
                      value: _alipayTopUpExperienced,
                      onChanged: (value) =>
                          setState(() => _alipayTopUpExperienced = value),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      steps[_page],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: 3,
                        onPageChanged: (page) => setState(() => _page = page),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _InstructionImageStep(index: index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < 3; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _page ? 22 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? context.brandPrimary
                                  : const Color(0xFFE3E5EA),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + bottomPadding),
              child: SelfBuyoutPrimaryButton(
                label: tr(context, ru: 'Понятно, продолжить', zh: '明白，继续'),
                icon: Icons.arrow_forward_rounded,
                onTap: _alipayTopUpExperienced == null
                    ? null
                    : () => Navigator.of(context).pop(_alipayTopUpExperienced),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperienceQuestion extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _ExperienceQuestion({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              ru: 'Пополняли ли Вы ранее Alipay хотя бы 3 раза?',
              zh: '您以前是否至少充值过 3 次支付宝？',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14.5,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ExperienceOption(
                  label: tr(context, ru: 'Да', zh: '是'),
                  selected: value == true,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExperienceOption(
                  label: tr(context, ru: 'Нет', zh: '否'),
                  selected: value == false,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExperienceOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExperienceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.brandPrimary : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? context.brandPrimary
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionImageStep extends StatelessWidget {
  final int index;

  const _InstructionImageStep({required this.index});

  @override
  Widget build(BuildContext context) {
    final alignment = switch (index) {
      0 => Alignment.centerLeft,
      1 => Alignment.center,
      _ => Alignment.centerRight,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: ClipRect(
            child: Align(
              alignment: alignment,
              widthFactor: 1 / 3,
              child: Image.asset(
                _instructionAsset,
                width: 1280,
                height: 743,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
