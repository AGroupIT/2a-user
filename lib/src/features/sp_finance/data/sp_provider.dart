import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'sp_models.dart';
import 'sp_repository.dart';

/// Провайдер репозитория СП
final spRepositoryProvider = Provider<SpRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SpRepository(apiClient);
});

/// Состояние списка сборок СП
class SpAssembliesState {
  final List<SpAssembly> assemblies;
  final bool isLoading;
  final String? error;

  const SpAssembliesState({
    this.assemblies = const [],
    this.isLoading = false,
    this.error,
  });

  SpAssembliesState copyWith({
    List<SpAssembly>? assemblies,
    bool? isLoading,
    String? error,
  }) {
    return SpAssembliesState(
      assemblies: assemblies ?? this.assemblies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Контроллер для списка сборок СП
class SpAssembliesController extends Notifier<SpAssembliesState> {
  @override
  SpAssembliesState build() {
    // Не вызываем loadAssemblies() в build() - это создает circular dependency
    // Вместо этого вызовем из initState экрана
    return const SpAssembliesState();
  }

  /// Загрузить список сборок
  Future<void> loadAssemblies() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = ref.read(spRepositoryProvider);
      final assemblies = await repository.getAssemblies();

      debugPrint('✅ SP: Loaded ${assemblies.length} assemblies');

      state = state.copyWith(
        assemblies: assemblies,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ SP: Error loading assemblies: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Обновить настройки сборки
  Future<void> updateAssembly(int assemblyId, SpAssemblyUpdate update) async {
    try {
      final repository = ref.read(spRepositoryProvider);
      final updatedAssembly = await repository.updateAssembly(assemblyId, update);

      // Обновляем сборку в списке
      final assemblies = state.assemblies.map((a) {
        return a.id == assemblyId ? updatedAssembly : a;
      }).toList();

      state = state.copyWith(assemblies: assemblies);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Распределить доставку по весу
  Future<void> calculateShipping(int assemblyId) async {
    try {
      final repository = ref.read(spRepositoryProvider);
      final updatedAssembly = await repository.calculateShipping(assemblyId);

      // Обновляем сборку в списке
      final assemblies = state.assemblies.map((a) {
        return a.id == assemblyId ? updatedAssembly : a;
      }).toList();

      state = state.copyWith(assemblies: assemblies);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Применить курс по умолчанию
  Future<void> applyRate(int assemblyId) async {
    try {
      final repository = ref.read(spRepositoryProvider);
      final updatedAssembly = await repository.applyRate(assemblyId);

      // Обновляем сборку в списке
      final assemblies = state.assemblies.map((a) {
        return a.id == assemblyId ? updatedAssembly : a;
      }).toList();

      state = state.copyWith(assemblies: assemblies);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Переключить статус оплаты участника
  Future<bool> toggleParticipantPayment(
    int assemblyId,
    String participantName,
    bool isPaid,
  ) async {
    try {
      final repository = ref.read(spRepositoryProvider);
      await repository.updateParticipantPayment(assemblyId, participantName, isPaid);

      // Обновляем состояние локально
      final assemblies = state.assemblies.map((assembly) {
        if (assembly.id != assemblyId) return assembly;

        // Обновляем участника в stats
        final updatedParticipants = assembly.stats.participants.map((p) {
          if (p.name != participantName) return p;
          return p.copyWith(isPaid: isPaid);
        }).toList();

        return assembly.copyWith(
          stats: assembly.stats.copyWith(participants: updatedParticipants),
        );
      }).toList();

      state = state.copyWith(assemblies: assemblies);
      return true;
    } catch (e) {
      debugPrint('❌ SP: Error updating participant payment: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Провайдер контроллера списка сборок
final spAssembliesControllerProvider =
    NotifierProvider<SpAssembliesController, SpAssembliesState>(
  SpAssembliesController.new,
);

/// Состояние редактирования трека
class SpTrackEditState {
  final SpTrack? track;
  final bool isSaving;
  final String? error;

  const SpTrackEditState({
    this.track,
    this.isSaving = false,
    this.error,
  });

  SpTrackEditState copyWith({
    SpTrack? track,
    bool? isSaving,
    String? error,
  }) {
    return SpTrackEditState(
      track: track ?? this.track,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

/// Контроллер для редактирования трека
class SpTrackEditController extends Notifier<SpTrackEditState> {
  @override
  SpTrackEditState build() {
    return const SpTrackEditState();
  }

  /// Установить трек для редактирования
  void setTrack(SpTrack track) {
    state = state.copyWith(track: track);
  }

  /// Обновить трек
  Future<bool> updateTrack(int trackId, SpTrackUpdate update) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      final repository = ref.read(spRepositoryProvider);
      final updatedTrack = await repository.updateTrack(trackId, update);

      state = state.copyWith(
        track: updatedTrack,
        isSaving: false,
      );

      // Обновляем трек в списке сборок
      ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();

      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

/// Провайдер контроллера редактирования трека
final spTrackEditControllerProvider =
    NotifierProvider<SpTrackEditController, SpTrackEditState>(
  SpTrackEditController.new,
);
