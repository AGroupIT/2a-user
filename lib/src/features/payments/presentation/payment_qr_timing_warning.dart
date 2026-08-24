import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';

Future<void> showPaymentQrTimingWarning(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => const _PaymentQrTimingWarningDialog(),
  );
}

class _PaymentQrTimingWarningDialog extends StatelessWidget {
  const _PaymentQrTimingWarningDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, ru: 'Важно об оплате по QR', zh: '二维码付款重要提示'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
                  ru: 'Если вы оплатите по этому QR после уведомления о том, что менеджеры по оплатам отдыхают, платёж будет зачислен на следующий день — по курсу юаня, актуальному на следующий день. Из-за изменения курса может потребоваться доплата.\n\nЧтобы избежать недоразумений, сразу после получения QR-кода произведите оплату, загрузите чек и нажмите «Я оплатил».',
                  zh: '如果您在收到“支付经理已休息”的通知后才使用此二维码付款，款项将在次日按照次日有效的人民币汇率入账。因此，汇率变动可能导致需要补款。\n\n为避免误解，请在获取二维码后立即完成付款，上传付款凭证并点击「我已付款」。',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 15,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(tr(context, ru: 'Я понял', zh: '我明白了')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
