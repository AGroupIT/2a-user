import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/stale_data_cache.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../clients/domain/client_codes_state.dart';
import '../../shell/application/shell_branch_provider.dart';
import '../presentation/training_target.dart';

const assemblyTrainingClientCode = 'TRAINING-ONLY';
const assemblyTrainingClientId = 910001;
const assemblyTrainingClientCodeId = 910002;
const assemblyTrainingTrackIds = [910101, 910102, 910103];
const assemblyTrainingTrackCodes = [
  'TRAINING-001',
  'TRAINING-002',
  'TRAINING-003',
];
const assemblyTrainingTariffId = 910201;
const assemblyTrainingPackagingId = 910301;
const assemblyTrainingAssemblyId = 910401;
const assemblyTrainingAssemblyNumber = 'TRAINING-ASSEMBLY-001';

/// Uses the production widgets, providers and API services in an independent
/// container. The transport has no network implementation or fallback.
class AssemblyTrainingSession extends ChangeNotifier {
  late final ProviderContainer container;
  late final _TrainingTransport _transport;
  bool _disposed = false;

  AssemblyTrainingSession({required TrainingTargetRegistry registry}) {
    _transport = _TrainingTransport(
      onCreated: () {
        if (!_disposed) notifyListeners();
      },
    );
    final api = _TrainingApiClient(_transport);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(_TrainingAuth.new),
        clientCodesControllerProvider.overrideWith(_TrainingClientCodes.new),
        activeClientCodeProvider.overrideWithValue(assemblyTrainingClientCode),
        activeClientCodeIdProvider.overrideWithValue(
          assemblyTrainingClientCodeId,
        ),
        activeShellBranchIndexProvider.overrideWith(_TrainingShellBranch.new),
        staleDataCacheEnabledProvider.overrideWithValue(false),
        trainingTargetRegistryProvider.overrideWithValue(registry),
      ],
    );
  }

  bool get assemblyCreated => _transport.assembly != null;
  Map<String, dynamic>? get submittedPayload => _transport.submittedPayload;
  List<String> get rejectedRequests =>
      List.unmodifiable(_transport.rejectedRequests);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    _transport.close(force: true);
    super.dispose();
  }
}

class _TrainingAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    isLoading: false,
    userDomain: 'training.invalid',
    clientId: assemblyTrainingClientId,
    clientName: 'TRAINING',
    clientData: {
      'codes': [
        {
          'id': assemblyTrainingClientCodeId,
          'code': assemblyTrainingClientCode,
        },
      ],
    },
  );
}

class _TrainingClientCodes extends ClientCodesController {
  @override
  Future<ClientCodesState> build() async => const ClientCodesState(
    codes: [assemblyTrainingClientCode],
    activeCode: assemblyTrainingClientCode,
  );

  @override
  Future<void> selectClient(String code) async {}
}

class _TrainingShellBranch extends ActiveShellBranchIndexNotifier {
  @override
  int build() => ShellBranchIndex.home;

  @override
  void setIndex(int index) {}
}

class _TrainingApiClient extends ApiClient {
  _TrainingApiClient(_TrainingTransport transport)
    : super(adapterFactory: () => transport, runtimeHeaders: () async => {});

  @override
  String get activeBaseUrl => 'https://training.invalid/api';

  // ApiClient normally reads a process-wide token cache. A training request
  // must not even read credentials from the user's account.
  @override
  Future<String?> getToken() async => null;
}

class _TrainingTransport implements HttpClientAdapter {
  final VoidCallback onCreated;
  final rejectedRequests = <String>[];
  final List<Map<String, dynamic>> _tracks;
  Map<String, dynamic>? assembly;
  Map<String, dynamic>? submittedPayload;
  bool _closed = false;

  _TrainingTransport({required this.onCreated}) : _tracks = _initialTracks();

  @override
  void close({bool force = false}) => _closed = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('Training session is closed');
    // Dio carries the app base URL, but this adapter only inspects the path:
    // it never delegates, opens sockets, or constructs a network adapter.
    final path = options.path;
    final query = options.queryParameters;
    if (options.method == 'GET') {
      if (path == '/statuses') {
        return _response({'data': _statuses(query['type']?.toString() ?? '')});
      }
      if (path == '/tariffs') return _response({'tariffs': _tariffs});
      if (path == '/packagings') return _response({'packagings': _packagings});
      if (path == '/tracks' &&
          query['clientCode'] == assemblyTrainingClientCode) {
        var rows = _tracks.where((track) {
          if (query['hasAssembly'] == 'true' && track['assembly'] == null) {
            return false;
          }
          if (query['assemblyId'] == 'null' && track['assembly'] != null) {
            return false;
          }
          if (query['status'] != null && query['status'] != track['status']) {
            return false;
          }
          if (query['assemblyStatus'] != null &&
              query['assemblyStatus'] !=
                  (track['assembly'] as Map?)?['status']) {
            return false;
          }
          final search = query['search']?.toString().toLowerCase() ?? '';
          if (!track['code'].toString().toLowerCase().contains(search)) {
            return false;
          }
          if (query['productInfo'] == 'filled' &&
              (track['productInfo'] as List).isEmpty) {
            return false;
          }
          if (query['productInfo'] == 'empty' &&
              (track['productInfo'] as List).isNotEmpty) {
            return false;
          }
          return true;
        }).toList();
        final total = rows.length;
        final skip = int.tryParse('${query['skip']}') ?? 0;
        final take = int.tryParse('${query['take']}') ?? 50;
        rows = rows
            .skip(skip < 0 ? 0 : skip)
            .take(take < 0 ? 0 : take)
            .toList();
        return _response({
          'data': rows,
          'total': total,
          'hasMore': skip + rows.length < total,
        });
      }
      if (path == '/assemblies' &&
          query['clientCode'] == assemblyTrainingClientCode) {
        return _response({
          'assemblies': [if (assembly != null) assembly],
          'pagination': {'total': assembly == null ? 0 : 1},
        });
      }
      if (path == '/assemblies/$assemblyTrainingAssemblyId' &&
          assembly != null) {
        return _response(assembly!);
      }
    }
    if (options.method == 'POST' && path == '/assemblies') {
      final data = options.data;
      if (data is Map<String, dynamic> && _validSubmission(data)) {
        submittedPayload = Map.unmodifiable(
          jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
        );
        final selectedIds = (data['trackIds'] as List).cast<int>();
        final now = DateTime.now().toUtc().toIso8601String();
        assembly = {
          'id': assemblyTrainingAssemblyId,
          'number': assemblyTrainingAssemblyNumber,
          'name': 'TRAINING',
          'status': 'new',
          'statusName': 'Новая',
          'statusColor': '#3B82F6',
          'clientCode': assemblyTrainingClientCode,
          'tariffName': _tariffs.first['name'],
          'packagingNames': [
            for (final p in _packagings)
              if ((data['packagingTypeIds'] as List).contains(p['id']))
                p['name'],
          ],
          'hasInsurance': data['hasInsurance'] == true,
          'insuranceAmount': data['insuranceAmount'],
          'hasFragileGoods': data['hasFragileGoods'] == true,
          'placePreference': data['placePreference'],
          'goodsDescription': data['goodsDescription'],
          'trackCount': selectedIds.length,
          'tracks': [
            for (final t in _tracks)
              if (selectedIds.contains(t['id']))
                {'id': t['id'], 'trackNumber': t['code']},
          ],
          'boxes': <dynamic>[],
          'createdAt': now,
          'updatedAt': now,
        };
        for (final track in _tracks.where(
          (t) => selectedIds.contains(t['id']),
        )) {
          track.addAll({
            'assemblyId': assemblyTrainingAssemblyId,
            'assembly': assembly,
            'status': 'in_assembly',
            'statusName': 'На сборке',
            'statusColor': '#F59E0B',
            'canAddToAssembly': false,
          });
        }
        onCreated();
        return _response(assembly!, status: 201);
      }
    }
    rejectedRequests.add('${options.method} $path');
    return _response({
      'code': 'TRAINING_REQUEST_REJECTED',
      'error': 'This action is outside the assembly exercise.',
    }, status: 422);
  }

  bool _validSubmission(Map<String, dynamic> data) {
    if (assembly != null ||
        data['clientId'] != assemblyTrainingClientId ||
        data['clientCodeId'] != assemblyTrainingClientCodeId ||
        data['tariffId'] != assemblyTrainingTariffId) {
      return false;
    }
    final ids = data['trackIds'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        !ids.every(
          (id) => _tracks.any(
            (t) => t['id'] == id && t['canAddToAssembly'] == true,
          ),
        )) {
      return false;
    }
    final packs = data['packagingTypeIds'];
    if (packs is! List ||
        !packs.contains(assemblyTrainingPackagingId) ||
        !packs.every((id) => _packagings.any((p) => p['id'] == id))) {
      return false;
    }
    if (!const [
      'single_if_possible',
      'split_allowed',
    ].contains(data['placePreference'])) {
      return false;
    }
    final missingInfo = _tracks.any(
      (t) => ids.contains(t['id']) && (t['productInfo'] as List).isEmpty,
    );
    if (missingInfo &&
        (data['goodsDescription']?.toString().trim().isEmpty ?? true)) {
      return false;
    }
    if (data['hasInsurance'] == true &&
        (data['insuranceAmount'] is! num ||
            (data['insuranceAmount'] as num) <= 0)) {
      return false;
    }
    return true;
  }
}

ResponseBody _response(Map<String, dynamic> data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _tariffs = [
  {
    'id': assemblyTrainingTariffId,
    'name': 'TRAINING — Standard',
    'baseCost': 2.5,
    'isActive': true,
    'requiresProductInfo': true,
  },
];
const _packagings = [
  {
    'id': assemblyTrainingPackagingId,
    'name': 'TRAINING — Box',
    'kind': 'primary',
    'suitableForFragileGoods': true,
    'baseCost': 0,
  },
  {
    'id': 910302,
    'name': 'TRAINING — Protection',
    'kind': 'addon',
    'suitableForFragileGoods': true,
    'baseCost': 0,
  },
];

List<Map<String, dynamic>> _initialTracks() => [
  for (var i = 0; i < assemblyTrainingTrackIds.length; i++)
    {
      'id': assemblyTrainingTrackIds[i],
      'code': assemblyTrainingTrackCodes[i],
      'status': i < 2 ? 'in_warehouse' : 'pending',
      'statusName': i < 2 ? 'На складе' : 'В ожидании',
      'statusColor': i < 2 ? '#22C55E' : '#F59E0B',
      'clientCode': {
        'id': assemblyTrainingClientCodeId,
        'code': assemblyTrainingClientCode,
      },
      'canAddToAssembly': i < 2,
      'createdAt': '2020-01-0${3 - i}T00:00:00.000Z',
      'updatedAt': '2020-01-02T00:00:00.000Z',
      'note': i == 1 ? 'TRAINING — Socks, 3 pairs' : null,
      'productInfo': [
        if (i == 0)
          {'id': 910501, 'name': 'TRAINING — T-shirts', 'quantity': 2},
      ],
      'photos': <dynamic>[],
      'photoRequests': <dynamic>[],
      'questions': <dynamic>[],
    },
];

// Snapshot of backend/docs/STATUS_MIGRATION.md. Only this isolated transport
// supplies fixtures; the signed-in application's statuses still come from API.
List<Map<String, dynamic>> _statuses(String type) {
  final entries = switch (type) {
    'track' => const [
      ('pending', 'В ожидании'),
      ('in_warehouse', 'На складе'),
      ('in_assembly', 'На сборке'),
      ('shipped', 'Отправлен'),
      ('arrived_terminal', 'Прибыл на терминал'),
      ('ready_for_pickup', 'Сформирован к выдаче'),
      ('delivered', 'Доставлен'),
      ('return_requested', 'Запрошен возврат'),
      ('returned', 'Возвращён'),
    ],
    'assembly' => const [
      ('new', 'Новая'),
      ('in_warehouse', 'На складе'),
      ('in_assembly', 'На сборке'),
      ('ready_to_ship', 'Готова к отправке'),
      ('shipped', 'Отправлена'),
      ('arrived_terminal', 'Прибыла на терминал'),
      ('ready_for_pickup', 'Сформирована к выдаче'),
      ('delivered', 'Доставлена'),
    ],
    'photo_request' || 'question' => const [
      ('new', 'Новый'),
      ('at_warehouse', 'На складе'),
      ('in_progress', 'В работе'),
      ('assigned', 'Назначен'),
      ('completed', 'Завершён'),
      ('cancelled', 'Отменён'),
    ],
    _ => const <(String, String)>[],
  };
  return [
    for (var i = 0; i < entries.length; i++)
      {
        'id': 911000 + i,
        'type': type,
        'code': entries[i].$1,
        'nameRu': entries[i].$2,
        'nameZh': entries[i].$1,
        'color': '#3B82F6',
        'sortOrder': i + 1,
        'isActive': true,
      },
  ];
}
