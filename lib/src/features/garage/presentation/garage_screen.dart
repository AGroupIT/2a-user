import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_request_detail_screen.dart';
import 'garage_request_form_screen.dart';
import 'garage_ui.dart';
import 'garage_vehicle_form_screen.dart';

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  int _section = 0;

  Future<void> _refresh() async {
    ref.invalidate(garageAvailabilityProvider);
    ref.invalidate(garageVehiclesControllerProvider);
    ref.invalidate(garageRequestsProvider);
    await Future.wait([
      ref.read(garageAvailabilityProvider.future),
      ref.read(garageVehiclesControllerProvider.future),
      ref.read(garageRequestsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(garageAvailabilityProvider);
    final top = AppLayout.topBarTotalHeight(context);
    final bottom = AppLayout.bottomScrollPadding(context);

    Widget page(List<Widget> children) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 22),
      children: [
        const GaragePageHeader(title: 'Гараж', fallbackLocation: '/'),
        const SizedBox(height: 12),
        ...children,
      ],
    );

    return availability.when(
      loading: () => page(const [
        GarageCard(child: Center(child: CircularProgressIndicator())),
      ]),
      error: (error, _) => page([
        _AccessMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Не удалось проверить доступ',
          subtitle: 'Потяните экран вниз или повторите позже.',
          onRetry: () => ref.invalidate(garageAvailabilityProvider),
        ),
      ]),
      data: (access) {
        if (!access.available) {
          return page([
            _AccessMessage(
              icon: Icons.garage_outlined,
              title: 'Гараж пока недоступен',
              subtitle: _availabilityText(access.reason),
              onRetry: () => ref.invalidate(garageAvailabilityProvider),
            ),
          ]);
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: context.brandPrimary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 22),
            children: [
              const GaragePageHeader(title: 'Гараж', fallbackLocation: '/'),
              const SizedBox(height: 12),
              _buildHero(context),
              const SizedBox(height: 18),
              _buildSectionPicker(context),
              const SizedBox(height: 14),
              switch (_section) {
                0 => _VehiclesSection(ref: ref),
                _ => _RequestsSection(ref: ref),
              },
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context) {
    final vehicles =
        ref.watch(garageVehiclesControllerProvider).asData?.value.vehicles ??
        const <GarageVehicle>[];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.20),
            blurRadius: 26,
            spreadRadius: -14,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Подбор запчастей',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте автомобиль и отправьте список деталей — менеджер подберёт подходящие варианты.',
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final buttons = [
                _HeroAction(
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Добавить авто',
                  onTap: () => showGarageVehicleFormModal(context),
                ),
                _HeroAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'Новая заявка',
                  onTap: () {
                    if (vehicles.isEmpty) {
                      AppToast.show(
                        context,
                        'Сначала добавьте автомобиль',
                        icon: Icons.info_outline_rounded,
                      );
                      return;
                    }
                    _openRequestForm(context);
                  },
                ),
              ];
              return compact
                  ? Column(
                      children: [
                        for (
                          var index = 0;
                          index < buttons.length;
                          index++
                        ) ...[
                          SizedBox(
                            width: double.infinity,
                            child: buttons[index],
                          ),
                          if (index == 0) const SizedBox(height: 6),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 10),
                        Expanded(child: buttons[1]),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestForm(BuildContext context) async {
    final requestId = await showGarageRequestFormModal(context);
    if (!context.mounted || requestId == null) return;
    await showGarageRequestDetailModal(context, requestId: requestId);
  }

  Widget _buildSectionPicker(BuildContext context) {
    return GarageSegmentedControl(
      selectedIndex: _section,
      items: const [
        (icon: Icons.directions_car_rounded, label: 'Автомобили'),
        (icon: Icons.assignment_rounded, label: 'Заявки'),
      ],
      onChanged: (index) => setState(() => _section = index),
    );
  }
}

class _VehiclesSection extends StatelessWidget {
  final WidgetRef ref;

  const _VehiclesSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(garageVehiclesControllerProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _InlineError(
        text: 'Не удалось загрузить автомобили',
        onRetry: () => ref.invalidate(garageVehiclesControllerProvider),
      ),
      data: (data) {
        if (data.vehicles.isEmpty) {
          return GarageEmptyState(
            icon: Icons.directions_car_outlined,
            title: 'Автомобилей пока нет',
            subtitle: 'Добавьте VIN и основные данные автомобиля.',
            action: GarageSecondaryButton(
              label: 'Добавить автомобиль',
              icon: Icons.add_rounded,
              onPressed: () => showGarageVehicleFormModal(context),
            ),
          );
        }
        return Column(
          children: [
            for (final vehicle in data.vehicles) ...[
              GarageCard(
                onTap: () =>
                    showGarageVehicleFormModal(context, vehicleId: vehicle.id),
                child: Row(
                  children: [
                    _RoundIcon(icon: Icons.directions_car_filled_rounded),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleTitle(vehicle),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _vehicleSubtitle(vehicle),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (vehicle.activeRequestCount > 0) ...[
                            const SizedBox(height: 7),
                            Text(
                              'Активных заявок: ${vehicle.activeRequestCount}',
                              style: TextStyle(
                                color: context.brandPrimary,
                                fontFamily: 'Gilroy',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RequestsSection extends StatelessWidget {
  final WidgetRef ref;

  const _RequestsSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(garageRequestsProvider);
    final requestStatuses =
        ref.watch(garageRequestStatusesProvider).asData?.value ??
        const <GarageRequestStatusDefinition>[];
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _InlineError(
        text: 'Не удалось загрузить заявки',
        onRetry: () => ref.invalidate(garageRequestsProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const GarageEmptyState(
            icon: Icons.assignment_outlined,
            title: 'Заявок пока нет',
            subtitle: 'Создайте заявку и добавьте несколько позиций.',
          );
        }
        return Column(
          children: [
            for (final request in rows) ...[
              Builder(
                builder: (context) {
                  final status = canonicalGarageRequestStatus(
                    request.status,
                    order: request.order,
                  );
                  final createdAt = request.createdAt;
                  return GarageCard(
                    onTap: () => showGarageRequestDetailModal(
                      context,
                      requestId: request.id,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RoundIcon(icon: Icons.receipt_long_rounded),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request.requestNumber,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontFamily: 'Gilroy',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  GarageStatusChip(
                                    status: status,
                                    definition: garageRequestStatusDefinition(
                                      requestStatuses,
                                      status,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_partsCountLabel(request.items.length)}'
                                '${createdAt == null ? '' : ' · ${_dateLabel(createdAt)}'}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Gilroy',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _snapshotLabel(request.vehicleSnapshot),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Gilroy',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.brandPrimary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _vehicleTitle(GarageVehicle vehicle) {
  final nickname = vehicle.nickname?.trim() ?? '';
  if (nickname.isNotEmpty) return nickname;
  return [
    vehicle.make,
    vehicle.model,
    vehicle.modelYear.toString(),
  ].where((value) => value.trim().isNotEmpty).join(' ');
}

String _vehicleSubtitle(GarageVehicle vehicle) {
  final nickname = vehicle.nickname?.trim() ?? '';
  final vehicleName = [
    vehicle.make,
    vehicle.model,
    vehicle.modelYear.toString(),
  ].where((value) => value.trim().isNotEmpty).join(' ');
  if (nickname.isNotEmpty &&
      vehicleName.isNotEmpty &&
      nickname != vehicleName) {
    return '$vehicleName · VIN ${vehicle.vinNormalized}';
  }
  return 'VIN ${vehicle.vinNormalized}';
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;

  const _RoundIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: context.brandPrimary, size: 24),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _InlineError({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GarageEmptyState(
      icon: Icons.error_outline_rounded,
      title: text,
      subtitle: 'Проверьте соединение и повторите.',
      action: GarageSecondaryButton(
        label: 'Повторить',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}

class _AccessMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _AccessMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GarageEmptyState(
            icon: icon,
            title: title,
            subtitle: subtitle,
            action: GarageSecondaryButton(
              label: 'Проверить снова',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

String _snapshotLabel(Map<String, dynamic>? snapshot) {
  if (snapshot == null) return 'автомобиль';
  final make = snapshot['make']?.toString().trim() ?? '';
  final model = snapshot['model']?.toString().trim() ?? '';
  final year = snapshot['modelYear']?.toString().trim() ?? '';
  return [make, model, year].where((value) => value.isNotEmpty).join(' ');
}

String _partsCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final suffix = mod10 == 1 && mod100 != 11
      ? 'запчасть'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'запчасти'
      : 'запчастей';
  return '$count $suffix';
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

String _availabilityText(String? reason) {
  return switch (reason) {
    'client_disabled' => 'Агент ещё не включил Гараж для вашего аккаунта.',
    'agent_disabled' ||
    'feature_disabled' => 'Сервис временно выключен вашим агентом.',
    _ => 'Сервис пока недоступен. Попробуйте позднее.',
  };
}
