import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/empty_state.dart';
import '../../../core/ui/glass_surface.dart';
import '../../../core/ui/sheet_handle.dart';
import '../application/client_codes_controller.dart';

class ClientSwitcherSheet extends ConsumerStatefulWidget {
  const ClientSwitcherSheet({super.key});

  @override
  ConsumerState<ClientSwitcherSheet> createState() => _ClientSwitcherSheetState();
}

class _ClientSwitcherSheetState extends ConsumerState<ClientSwitcherSheet> {
  final _codeCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(clientCodesControllerProvider.notifier).addClient(
            code: _codeCtrl.text,
            pin: _pinCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(clientCodesControllerProvider);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: asyncState.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить коды',
            message: e.toString(),
          ),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        // Список кодов - компактные chips по 3 в строку
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - 16) / 3; // 8px spacing * 2
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
                                        await ref.read(clientCodesControllerProvider.notifier).selectClient(code);
                                        if (context.mounted) Navigator.of(context).pop();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected ? const Color(0xFFff5f02).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected ? const Color(0xFFff5f02) : Colors.transparent,
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
                                                  ? const LinearGradient(colors: [Color(0xFFfe3301), Color(0xFFff5f02)])
                                                  : null,
                                                color: selected ? null : Colors.grey.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  selected ? Icons.check_rounded : Icons.circle,
                                                  color: selected ? Colors.white : Colors.grey,
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
                                                  color: selected ? const Color(0xFFff5f02) : Colors.black87,
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
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Добавить код',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Код клиента',
                            hintText: 'Например, 2A-12',
                            filled: true,
                            fillColor: Colors.grey.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFff5f02), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pinCtrl,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: InputDecoration(
                            labelText: 'PIN (4 цифры)',
                            hintText: '••••',
                            filled: true,
                            fillColor: Colors.grey.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFff5f02), width: 2),
                            ),
                          ),
                          onSubmitted: (_) => _submitting ? null : _add(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFfe3301), Color(0xFFff5f02)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFff5f02).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _submitting ? null : _add,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Text(
                                  _submitting ? 'Добавление…' : 'Добавить',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
