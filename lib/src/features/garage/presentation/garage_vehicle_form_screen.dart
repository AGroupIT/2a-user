import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_modal.dart';
import 'garage_ui.dart';

Future<bool?> showGarageVehicleFormModal(
  BuildContext context, {
  int? vehicleId,
}) {
  return showGarageModalSheet<bool>(
    context: context,
    child: GarageVehicleFormScreen(vehicleId: vehicleId, modal: true),
  );
}

class GarageVehicleFormScreen extends ConsumerStatefulWidget {
  final int? vehicleId;
  final bool modal;

  const GarageVehicleFormScreen({
    super.key,
    this.vehicleId,
    this.modal = false,
  });

  @override
  ConsumerState<GarageVehicleFormScreen> createState() =>
      _GarageVehicleFormScreenState();
}

class _GarageVehicleFormScreenState
    extends ConsumerState<GarageVehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vin = TextEditingController();
  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _generation = TextEditingController();
  final _engine = TextEditingController();
  final _comment = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  GarageVehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleId != null) {
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    _vin.dispose();
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _generation.dispose();
    _engine.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cached = ref
          .read(garageVehiclesControllerProvider)
          .asData
          ?.value
          .vehicles
          .where((vehicle) => vehicle.id == widget.vehicleId)
          .firstOrNull;
      final vehicle =
          cached ??
          await ref
              .read(garageRepositoryProvider)
              .getVehicle(widget.vehicleId!);
      if (!mounted) return;
      _vehicle = vehicle;
      _fill(vehicle);
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _show('Не удалось загрузить автомобиль', error: true);
    }
  }

  void _fill(GarageVehicle vehicle) {
    _vin.text = vehicle.vinNormalized;
    _nickname.text = vehicle.nickname ?? '';
    _make.text = vehicle.make;
    _model.text = vehicle.model;
    _year.text = vehicle.modelYear > 0 ? vehicle.modelYear.toString() : '';
    _generation.text = vehicle.generation ?? '';
    _engine.text = vehicle.engineCode ?? '';
    _comment.text = vehicle.comment ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final input = GarageVehicleInput(
      vin: _vin.text,
      nickname: _nickname.text,
      make: _make.text,
      model: _model.text,
      modelYear: int.parse(_year.text.trim()),
      generation: _generation.text,
      engineCode: _engine.text,
      comment: _comment.text,
    );
    try {
      final controller = ref.read(garageVehiclesControllerProvider.notifier);
      if (widget.vehicleId == null) {
        await controller.createVehicle(input);
      } else {
        await controller.updateVehicle(widget.vehicleId!, input);
      }
      if (!mounted) return;
      _show(
        widget.vehicleId == null
            ? 'Автомобиль добавлен'
            : 'Автомобиль обновлён',
      );
      if (widget.modal) {
        Navigator.of(context).pop(true);
      } else {
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show('Не удалось сохранить автомобиль', error: true);
    }
  }

  Future<void> _delete() async {
    final vehicle = _vehicle;
    if (vehicle == null || vehicle.activeRequestCount > 0 || _saving) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Удалить автомобиль?'),
            content: const Text(
              'Автомобиль будет скрыт из Гаража. История заявок сохранится.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(garageVehiclesControllerProvider.notifier)
          .deleteVehicle(vehicle.id);
      if (!mounted) return;
      if (widget.modal) {
        Navigator.of(context).pop(true);
      } else {
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show('Не удалось удалить автомобиль', error: true);
    }
  }

  void _show(String message, {bool error = false}) {
    AppToast.show(context, message, isError: error);
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.modal ? 0.0 : AppLayout.topBarTotalHeight(context);
    final bottom = widget.modal
        ? MediaQuery.viewInsetsOf(context).bottom + 24
        : AppLayout.bottomScrollPadding(context);
    final title = widget.vehicleId == null
        ? 'Добавление автомобиля'
        : 'Редактирование автомобиля';
    if (_loading) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.modal ? 0 : top * 0.7 + 16,
          16,
          bottom + 24,
        ),
        children: [
          if (widget.modal)
            GarageModalHeader(
              icon: Icons.directions_car_filled_rounded,
              title: title,
              subtitle: 'Данные автомобиля для подбора запчастей',
            )
          else
            GaragePageHeader(title: title),
          const SizedBox(height: 12),
          const GarageCard(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.modal ? 0 : top * 0.7 + 16,
          16,
          bottom + 24,
        ),
        children: [
          if (widget.modal)
            GarageModalHeader(
              icon: Icons.directions_car_filled_rounded,
              title: title,
              subtitle: 'Данные автомобиля для подбора запчастей',
            )
          else
            GaragePageHeader(title: title),
          const SizedBox(height: 12),
          GarageSectionCard(
            icon: Icons.badge_outlined,
            title: 'Основные данные',
            subtitle: 'VIN и понятное название автомобиля',
            child: Column(
              children: [
                TextFormField(
                  controller: _vin,
                  enabled: widget.vehicleId == null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-HJ-NPR-Za-hj-npr-z0-9]'),
                    ),
                    LengthLimitingTextInputFormatter(17),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'VIN',
                    hintText: '17 символов',
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[A-HJ-NPR-Z0-9]{17}$',
                      ).hasMatch((value ?? '').trim().toUpperCase())
                      ? null
                      : 'Введите корректный VIN',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nickname,
                  decoration: const InputDecoration(
                    labelText: 'Название в Гараже',
                    hintText: 'Например, Семейный автомобиль',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GarageSectionCard(
            icon: Icons.directions_car_outlined,
            title: 'Автомобиль',
            subtitle: 'Марка, модель и год выпуска',
            child: Column(
              children: [
                TextFormField(
                  controller: _make,
                  decoration: const InputDecoration(labelText: 'Марка *'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Модель *'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Год выпуска *'),
                  validator: (value) {
                    final year = int.tryParse(value ?? '');
                    final max = DateTime.now().year + 2;
                    return year != null && year >= 1886 && year <= max
                        ? null
                        : 'Введите год от 1886 до $max';
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GarageSectionCard(
            icon: Icons.tune_rounded,
            title: 'Дополнительно',
            subtitle: 'Комплектация и уточнения для менеджера',
            child: Column(
              children: [
                TextFormField(
                  controller: _generation,
                  decoration: const InputDecoration(
                    labelText: 'Поколение / комплектация',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _engine,
                  decoration: const InputDecoration(labelText: 'Код двигателя'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comment,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Комментарий'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GaragePrimaryButton(
            label: widget.vehicleId == null
                ? 'Добавить автомобиль'
                : 'Сохранить',
            icon: Icons.save_rounded,
            onPressed: _save,
            loading: _saving,
          ),
          if (widget.vehicleId != null) ...[
            const SizedBox(height: 10),
            GarageSecondaryButton(
              label: _vehicle?.activeRequestCount == 0
                  ? 'Удалить автомобиль'
                  : 'Нельзя удалить: есть активные заявки',
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              onPressed: _vehicle?.activeRequestCount == 0 ? _delete : null,
            ),
          ],
        ],
      ),
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Обязательное поле';
}
