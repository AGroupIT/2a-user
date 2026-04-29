import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/ui/app_colors.dart';
import '../../data/purchase_blank_model.dart';

/// Форма добавления / редактирования товара в бланке
class BlankItemForm extends StatefulWidget {
  /// Если передан — режим редактирования
  final PurchaseBlankItem? existingItem;

  /// Callback при сохранении
  final Future<void> Function({
    required String productName,
    required String productUrl,
    String? characteristics,
    required int quantity,
    required double unitPrice,
    List<Uint8List>? newPhotos,
    List<String>? newPhotoNames,
  })
  onSave;

  final VoidCallback? onCancel;

  const BlankItemForm({
    super.key,
    this.existingItem,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<BlankItemForm> createState() => _BlankItemFormState();
}

class _BlankItemFormState extends State<BlankItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _charCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  final List<_PickedPhoto> _pickedPhotos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameCtrl = TextEditingController(text: item?.productName ?? '');
    _urlCtrl = TextEditingController(text: item?.productUrl ?? '');
    _charCtrl = TextEditingController(text: item?.characteristics ?? '');
    _qtyCtrl = TextEditingController(
      text: item != null ? '${item.quantity}' : '1',
    );
    _priceCtrl = TextEditingController(
      text: item != null ? item.unitPrice.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _charCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (images.isEmpty) return;

    for (final xFile in images) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _pickedPhotos.add(_PickedPhoto(bytes: bytes, name: xFile.name));
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _pickedPhotos.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        productName: _nameCtrl.text.trim(),
        productUrl: _urlCtrl.text.trim(),
        characteristics: _charCtrl.text.trim().isEmpty
            ? null
            : _charCtrl.text.trim(),
        quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 1,
        unitPrice:
            double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0,
        newPhotos: _pickedPhotos.isNotEmpty
            ? _pickedPhotos.map((p) => p.bytes).toList()
            : null,
        newPhotoNames: _pickedPhotos.isNotEmpty
            ? _pickedPhotos.map((p) => p.name).toList()
            : null,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingItem != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Заголовок ──────────────────
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_rounded : Icons.add_rounded,
                  color: context.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Редактирование товара' : 'Новый товар',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Название товара ────────────
            _FormField(
              controller: _nameCtrl,
              label: 'Название товара *',
              hint: 'Например: Кроссовки Nike Air Max 90',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 12),

            // ── Ссылка на товар ────────────
            _FormField(
              controller: _urlCtrl,
              label: 'Ссылка на товар *',
              hint: 'https://...',
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
            ),
            const SizedBox(height: 12),

            // ── Характеристики ─────────────
            _FormField(
              controller: _charCtrl,
              label: 'Характеристики',
              hint: 'Размер, цвет, модель...',
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // ── Количество + Цена ──────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _FormField(
                    controller: _qtyCtrl,
                    label: 'Кол-во',
                    hint: '1',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 1) ? 'Мин. 1' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _FormField(
                    controller: _priceCtrl,
                    label: 'Цена за шт. (¥)',
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+[.,]?\d{0,2}'),
                      ),
                    ],
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (n == null || n <= 0) ? 'Укажите цену' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Фото ──────────────────────
            Text(
              'Фото товара',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Существующие фото (если редактирование)
                if (widget.existingItem != null)
                  ...widget.existingItem!.photoUrls.map(
                    (url) => _PhotoThumb(imageUrl: url),
                  ),
                // Новые фото
                ..._pickedPhotos.asMap().entries.map(
                  (e) => _PhotoThumb(
                    bytes: e.value.bytes,
                    onRemove: () => _removePhoto(e.key),
                  ),
                ),
                // Кнопка добавления
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Кнопка сохранения ─────────
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Сохранить' : 'Добавить товар',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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

// ── Поле формы ──────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.brandPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Модель выбранного фото ──────────────────────────────────

class _PickedPhoto {
  final Uint8List bytes;
  final String name;
  const _PickedPhoto({required this.bytes, required this.name});
}

// ── Миниатюра фото ─────────────────────────────────────────

class _PhotoThumb extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  const _PhotoThumb({this.imageUrl, this.bytes, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl != null
              ? Image.network(
                  ApiConfig.getMediaUrl(imageUrl!),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                )
              : Image.memory(bytes!, width: 64, height: 64, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
