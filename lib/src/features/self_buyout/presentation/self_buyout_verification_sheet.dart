import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/phone_input_field.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/locale_text.dart';
import '../data/self_buyout_models.dart';
import '../data/self_buyout_service.dart';
import 'self_buyout_ui.dart';

class SelfBuyoutVerificationSheet extends ConsumerStatefulWidget {
  final SelfBuyoutVerification verification;

  const SelfBuyoutVerificationSheet({super.key, required this.verification});

  @override
  ConsumerState<SelfBuyoutVerificationSheet> createState() =>
      _SelfBuyoutVerificationSheetState();
}

class _SelfBuyoutVerificationSheetState
    extends ConsumerState<SelfBuyoutVerificationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _telegramController;
  late final PhoneController _phoneController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.verification.contact;
    _fullNameController = TextEditingController(text: contact.fullName);
    _telegramController = TextEditingController(text: contact.telegram);
    _phoneController = PhoneController(
      initialValue:
          PhoneInputField.parse(contact.phone) ??
          const PhoneNumber(isoCode: IsoCode.RU, nsn: ''),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _telegramController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) {
      return tr(context, ru: 'Укажите ФИО', zh: '请输入姓名');
    }
    return null;
  }

  String? _validateTelegram(String? value) {
    var text = value?.trim() ?? '';
    text = text
        .replaceFirst(RegExp(r'^https?://(www\.)?t\.me/'), '')
        .replaceFirst(RegExp(r'^@'), '')
        .split(RegExp(r'[/?#]'))
        .first;
    if (!RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(text)) {
      return tr(
        context,
        ru: 'Укажите Telegram username, например @username',
        zh: '请输入 Telegram 用户名，例如 @username',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _phoneController.value;
    if (phone.nsn.trim().isEmpty || !phone.isValid()) {
      AppToast.show(
        context,
        tr(context, ru: 'Введите корректный номер телефона', zh: '请输入正确的电话号码'),
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final verification = await ref
          .read(selfBuyoutServiceProvider)
          .submitVerification(
            fullName: _fullNameController.text,
            phone: phone.international,
            telegram: _telegramController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(verification);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        tr(
          context,
          ru: 'Не удалось отправить данные. Попробуйте ещё раз.',
          zh: '提交失败，请重试。',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      bottom: false,
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SelfBuyoutGradientHeader(
                  icon: Icons.verified_user_rounded,
                  title: tr(
                    context,
                    ru: 'Проверка для самовыкупа',
                    zh: '自助代购验证',
                  ),
                  subtitle: tr(
                    context,
                    ru: 'Партнёр проверит контактные данные и откроет доступ.',
                    zh: '合作方将核实您的联系方式并开通权限。',
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5EE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.brandPrimary.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: context.brandPrimary,
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr(
                                    context,
                                    ru: 'У вашего аккаунта пока нет треков и связи с платёжным партнёром. До подтверждения создать заявку на самовыкуп нельзя.',
                                    zh: '您的账户暂无物流单号，也未关联支付合作方。验证通过前无法创建自助代购申请。',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Gilroy',
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: _validateName,
                          decoration: appInputDecoration(
                            context,
                            labelText: tr(context, ru: 'ФИО', zh: '姓名'),
                            hintText: tr(
                              context,
                              ru: 'Иванов Иван Иванович',
                              zh: '请输入姓名',
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                            fillColor: const Color(0xFFF8F8FA),
                            borderColor: const Color(0xFFE2E2E8),
                            radius: kAppInputLargeRadius,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PhoneInputField(
                          controller: _phoneController,
                          isRequired: true,
                          hintText: tr(
                            context,
                            ru: 'Номер телефона',
                            zh: '电话号码',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telegramController,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          validator: _validateTelegram,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: appInputDecoration(
                            context,
                            labelText: 'Telegram',
                            hintText: '@username',
                            prefixIcon: const Icon(Icons.send_rounded),
                            fillColor: const Color(0xFFF8F8FA),
                            borderColor: const Color(0xFFE2E2E8),
                            radius: kAppInputLargeRadius,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(
                            context,
                            ru: 'После отправки статус проверки обновится автоматически. При отказе самовыкуп останется недоступен. Доступ также откроется, если после отказа вы оплатите счёт на доставку.',
                            zh: '提交后状态将自动更新。如未通过，自助代购仍不可用；若在被拒后支付物流账单，也会自动开通。',
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Gilroy',
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomPadding),
                child: SelfBuyoutPrimaryButton(
                  label: tr(context, ru: 'Отправить на проверку', zh: '提交验证'),
                  icon: Icons.verified_rounded,
                  onTap: _submitting ? null : _submit,
                  isLoading: _submitting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
