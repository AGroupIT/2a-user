import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/demo_mode_provider.dart';

/// Persistent top banner shown while demo mode is active.
/// Styled like the app's floating SnackBar notifications.
class DemoModeBanner extends ConsumerWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemoMode = ref.watch(demoModeProvider);
    if (!isDemoMode) return const SizedBox.shrink();

    final topPad = MediaQuery.paddingOf(context).top;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFE3301), Color(0xFFFF8800)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33FE3301),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Режим обучения — показаны тестовые данные.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => ref.read(demoModeProvider.notifier).disable(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Завершить',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
