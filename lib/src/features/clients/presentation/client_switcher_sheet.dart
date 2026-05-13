import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/sheet_handle.dart';
import '../../../core/utils/error_utils.dart';
import '../application/client_codes_controller.dart';

class ClientSwitcherSheet extends ConsumerStatefulWidget {
  const ClientSwitcherSheet({super.key});

  @override
  ConsumerState<ClientSwitcherSheet> createState() =>
      _ClientSwitcherSheetState();
}

class _ClientSwitcherSheetState extends ConsumerState<ClientSwitcherSheet> {
  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(clientCodesControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: asyncState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) {
            final errorInfo = ErrorUtils.getErrorInfo(e);
            return EmptyState(
              icon: errorInfo.icon,
              title: errorInfo.title,
              message: errorInfo.message,
            );
          },
          data: (state) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Код клиента',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        // Список кодов - компактные chips по 2 в строку
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth =
                                (constraints.maxWidth - 8) /
                                2; // 8px spacing * 1
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: state.codes.map((code) {
                                final selected = code == state.activeCode;

                                return SizedBox(
                                  width: itemWidth,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        await ref
                                            .read(
                                              clientCodesControllerProvider
                                                  .notifier,
                                            )
                                            .selectClient(code);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? context.brandSecondary
                                                    .withValues(alpha: 0.1)
                                              : Colors.grey.withValues(
                                                  alpha: 0.05,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? context.brandSecondary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                gradient: selected
                                                    ? LinearGradient(
                                                        colors: [
                                                          context.brandPrimary,
                                                          context
                                                              .brandSecondary,
                                                        ],
                                                      )
                                                    : null,
                                                color: selected
                                                    ? null
                                                    : Colors.grey.withValues(
                                                        alpha: 0.2,
                                                      ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  selected
                                                      ? Icons.check_rounded
                                                      : Icons.circle,
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.grey,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                code,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: selected
                                                      ? context.brandSecondary
                                                      : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
