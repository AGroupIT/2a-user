import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../../clients/application/client_codes_controller.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_ui.dart';

class GarageRequestFormScreen extends ConsumerStatefulWidget {
  final int? initialVehicleId;
  final int? requestId;

  const GarageRequestFormScreen({
    super.key,
    this.initialVehicleId,
    this.requestId,
  });

  @override
  ConsumerState<GarageRequestFormScreen> createState() =>
      _GarageRequestFormScreenState();
}

class _GarageRequestFormScreenState
    extends ConsumerState<GarageRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  final _items = <_PartDraft>[_PartDraft()];
  final _deletedItemIds = <int>{};
  int? _vehicleId;
  int? _clientCodeId;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  bool get _isEditing => widget.requestId != null;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.initialVehicleId;
    _loading = _isEditing;
    Future<void>.microtask(_initialize);
  }

  @override
  void dispose() {
    _comment.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_PartDraft()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    final removed = _items.removeAt(index);
    if (removed.itemId != null) {
      _deletedItemIds.add(removed.itemId!);
    }
    removed.dispose();
    setState(() {});
  }

  Future<void> _initialize() async {
    final controller = ref.read(garageRequestDraftControllerProvider.notifier);
    if (!_isEditing) {
      controller.reset();
      return;
    }
    try {
      final request = await controller.load(widget.requestId!);
      if (!mounted) return;
      if (request.status != 'draft') {
        setState(() {
          _loading = false;
          _loadError = 'Эту заявку уже нельзя редактировать';
        });
        return;
      }
      for (final item in _items) {
        item.dispose();
      }
      setState(() {
        _vehicleId = request.vehicleId;
        _clientCodeId = request.clientCodeId;
        _comment.text = request.clientComment ?? '';
        _items
          ..clear()
          ..addAll(request.items.map(_PartDraft.fromItem));
        if (_items.isEmpty) {
          _items.add(_PartDraft());
        }
        _deletedItemIds.clear();
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Не удалось загрузить черновик';
      });
    }
  }

  Future<void> _persist({required bool submit}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_vehicleId == null) {
      _show('Выберите автомобиль', error: true);
      return;
    }
    final clientCodeId = _clientCodeId ?? ref.read(activeClientCodeIdProvider);
    if (clientCodeId == null) {
      _show('Не удалось определить активный код клиента', error: true);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(garageRequestDraftControllerProvider.notifier);
    try {
      var request = _isEditing
          ? await controller.update(
              GarageRequestUpdate(
                vehicleId: _vehicleId,
                clientCodeId: clientCodeId,
                clientComment: _comment.text,
              ),
            )
          : await controller.create(
              GarageRequestInput(
                vehicleId: _vehicleId!,
                clientCodeId: clientCodeId,
                clientComment: _comment.text,
              ),
              idempotencyKey: const Uuid().v4(),
            );
      for (final itemId in _deletedItemIds) {
        await controller.deleteItem(itemId);
      }
      for (final item in _items) {
        if (item.itemId == null) {
          await controller.addItem(item.toInput());
        } else {
          await controller.updateItem(item.itemId!, item.toInput());
        }
      }
      if (submit) {
        request = await controller.submit(idempotencyKey: const Uuid().v4());
      } else {
        request =
            ref.read(garageRequestDraftControllerProvider).request ?? request;
      }
      if (!mounted) return;
      ref.invalidate(garageRequestsProvider);
      ref.invalidate(garageRequestProvider(request.id));
      _show(submit ? 'Заявка отправлена' : 'Черновик сохранён');
      context.go('/garage/requests/${request.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (_isEditing) {
        _show('Не удалось сохранить изменения', error: true);
        return;
      }
      final partial = ref.read(garageRequestDraftControllerProvider).request;
      if (partial != null) {
        _show(
          'Черновик создан, но не все данные удалось сохранить. Откройте его и проверьте позиции.',
          error: true,
        );
        context.go('/garage/requests/${partial.id}');
      } else {
        _show('Не удалось сохранить заявку', error: true);
      }
    }
  }

  void _show(String message, {bool error = false}) {
    AppToast.show(context, message, isError: error);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(garageVehiclesControllerProvider);
    final top = AppLayout.topBarTotalHeight(context);
    final bottom = AppLayout.bottomScrollPadding(context);
    final title = _isEditing ? 'Редактирование заявки' : 'Новая заявка';

    if (_loading || _loadError != null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: [
          GaragePageHeader(title: title),
          const SizedBox(height: 12),
          if (_loading)
            const GarageCard(child: Center(child: CircularProgressIndicator()))
          else
            GarageEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Черновик не загрузился',
              subtitle: _loadError!,
              action: GarageSecondaryButton(
                label: 'Повторить',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _initialize();
                },
              ),
            ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: [
          GaragePageHeader(title: title),
          const SizedBox(height: 12),
          const GarageCard(
            child: Text(
              'Добавьте одну или несколько деталей. Черновик хранится на сервере, его можно дополнять и отправить отдельной кнопкой.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GarageCard(
            child: vehicles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => GarageSecondaryButton(
                label: 'Повторить загрузку автомобилей',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    ref.invalidate(garageVehiclesControllerProvider),
              ),
              data: (state) => Column(
                children: [
                  GarageVehiclePickerField(
                    vehicles: state.vehicles,
                    value:
                        state.vehicles.any(
                          (vehicle) => vehicle.id == _vehicleId,
                        )
                        ? _vehicleId
                        : null,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _vehicleId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Общий комментарий',
                      hintText: 'Пожелания по заявке',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _items.length; index++) ...[
            _PartCard(
              index: index,
              draft: _items[index],
              canRemove: _items.length > 1,
              enabled: !_saving,
              onRemove: () => _removeItem(index),
            ),
            const SizedBox(height: 12),
          ],
          GarageSecondaryButton(
            label: 'Добавить ещё одну позицию',
            icon: Icons.add_rounded,
            onPressed: _saving ? null : _addItem,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final draftButton = GarageSecondaryButton(
                label: _isEditing
                    ? 'Сохранить изменения'
                    : 'Сохранить черновик',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : () => _persist(submit: false),
              );
              final submitButton = GaragePrimaryButton(
                label: _isEditing
                    ? 'Сохранить и отправить'
                    : 'Отправить заявку',
                icon: Icons.send_rounded,
                onPressed: () => _persist(submit: true),
                loading: _saving,
              );
              if (compact) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: submitButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: draftButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: draftButton),
                  const SizedBox(width: 10),
                  Expanded(child: submitButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatefulWidget {
  final int index;
  final _PartDraft draft;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;

  const _PartCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.enabled,
    required this.onRemove,
  });

  @override
  State<_PartCard> createState() => _PartCardState();
}

class _PartCardState extends State<_PartCard> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Позиция ${widget.index + 1}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  tooltip: 'Удалить позицию',
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.redAccent,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.name,
            enabled: widget.enabled,
            decoration: const InputDecoration(labelText: 'Название детали *'),
            validator: _required,
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.number,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Артикул *'),
            validator: _required,
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.existUrl,
            enabled: widget.enabled,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Ссылка Exist.ru *',
              hintText: 'https://exist.ru/...',
            ),
            validator: _validateExistUrl,
          ),
          const SizedBox(height: 11),
          GaragePartPreferencePickerField(
            key: ValueKey('garage-part-preference-picker-${widget.index}'),
            value: draft.preference,
            enabled: widget.enabled,
            onChanged: (value) => setState(() => draft.preference = value),
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.quantity,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Количество *'),
            validator: (value) {
              final quantity = int.tryParse(value ?? '');
              return quantity != null && quantity > 0 && quantity <= 999
                  ? null
                  : 'От 1 до 999';
            },
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.side,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Сторона / расположение',
              hintText: 'Передняя левая',
            ),
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.position,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Позиция / место установки',
              hintText: 'Например, передняя ось',
            ),
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: draft.comment,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Комментарий'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Позиция необязательная'),
            subtitle: const Text('Можно исключить из итогового заказа'),
            value: draft.optional,
            onChanged: widget.enabled
                ? (value) => setState(() => draft.optional = value)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PartDraft {
  final int? itemId;
  final TextEditingController name;
  final TextEditingController number;
  final TextEditingController existUrl;
  final TextEditingController quantity;
  final TextEditingController side;
  final TextEditingController position;
  final TextEditingController comment;
  GaragePartPreference preference;
  bool optional;

  _PartDraft({GarageRequestItem? item})
    : itemId = item?.id,
      name = TextEditingController(text: item?.partName ?? ''),
      number = TextEditingController(text: item?.partNumber ?? ''),
      existUrl = TextEditingController(text: item?.existUrl ?? ''),
      quantity = TextEditingController(text: '${item?.quantity ?? 1}'),
      side = TextEditingController(text: item?.side ?? ''),
      position = TextEditingController(text: item?.position ?? ''),
      comment = TextEditingController(text: item?.clientComment ?? ''),
      preference = item?.preference ?? GaragePartPreference.any,
      optional = item?.isOptional ?? false;

  factory _PartDraft.fromItem(GarageRequestItem item) {
    return _PartDraft(item: item);
  }

  GarageRequestItemInput toInput() {
    return GarageRequestItemInput(
      partName: name.text,
      partNumber: number.text,
      preference: preference,
      existUrl: existUrl.text,
      quantity: int.parse(quantity.text),
      side: side.text,
      position: position.text,
      clientComment: comment.text,
      isOptional: optional,
    );
  }

  void dispose() {
    name.dispose();
    number.dispose();
    existUrl.dispose();
    quantity.dispose();
    side.dispose();
    position.dispose();
    comment.dispose();
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Обязательное поле';
}

String? _validateExistUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  final host = uri?.host.toLowerCase() ?? '';
  if (uri?.scheme != 'https' ||
      (host != 'exist.ru' && !host.endsWith('.exist.ru'))) {
    return 'Укажите HTTPS-ссылку Exist.ru';
  }
  return null;
}
