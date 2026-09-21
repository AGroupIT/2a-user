import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final garageTranslationServiceProvider = Provider<GarageTranslationService>((
  ref,
) {
  return GarageTranslationService(ref.watch(apiClientProvider));
});

class GarageTranslationService {
  final ApiClient _apiClient;
  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};
  Future<void> _translationTail = Future<void>.value();
  DateTime? _translationRetryAt;

  GarageTranslationService(this._apiClient);

  Future<String?> translateToRussian(String text) {
    final source = text.trim();
    if (source.isEmpty || !_containsChinese(source)) {
      return Future<String?>.value(source);
    }
    final cached = _cache[source];
    if (cached != null) return Future<String?>.value(cached);
    final pending = _inFlight[source];
    if (pending != null) return pending;
    if (_translationCoolingDown || _inFlight.length >= 64) {
      return Future<String?>.value(null);
    }

    // Карточки гаража монтируются пачкой. Последовательная очередь не даёт
    // одному экрану одновременно отправить множество запросов в Yandex.
    final result = _translationTail.then((_) => _translate(source));
    _inFlight[source] = result;
    _translationTail = result.then<void>(
      (_) => _inFlight.remove(source),
      onError: (Object error, StackTrace stackTrace) {
        _inFlight.remove(source);
      },
    );
    return result;
  }

  bool get _translationCoolingDown {
    final retryAt = _translationRetryAt;
    return retryAt != null && DateTime.now().isBefore(retryAt);
  }

  Future<String?> _translate(String source) async {
    if (_translationCoolingDown) return null;
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/translate',
        data: {'text': source, 'direction': 'zh-ru'},
      );
      final translated = response.data?['translation']?.toString().trim();
      if (translated == null || translated.isEmpty) return null;
      if (_cache.length >= 128) {
        _cache.remove(_cache.keys.first);
      }
      _cache[source] = translated;
      return translated;
    } on DioException catch (error) {
      final raw = error.response?.data;
      final retryAfterMs = raw is Map ? raw['retryAfterMs'] : null;
      final delayMs = retryAfterMs is num && retryAfterMs.isFinite
          ? retryAfterMs.toInt().clamp(30000, 300000)
          : 30000;
      _translationRetryAt = DateTime.now().add(Duration(milliseconds: delayMs));
      return null;
    } catch (_) {
      return null;
    }
  }
}

class GarageTranslatedText extends ConsumerStatefulWidget {
  final String text;
  final String? translatedText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const GarageTranslatedText(
    this.text, {
    super.key,
    this.translatedText,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  ConsumerState<GarageTranslatedText> createState() =>
      _GarageTranslatedTextState();
}

class _GarageTranslatedTextState extends ConsumerState<GarageTranslatedText> {
  String? _runtimeTranslation;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveTranslation());
  }

  @override
  void didUpdateWidget(covariant GarageTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.translatedText != widget.translatedText) {
      _runtimeTranslation = null;
      _requestVersion += 1;
      unawaited(_resolveTranslation());
    }
  }

  Future<void> _resolveTranslation() async {
    final backendTranslation = _normalized(widget.translatedText);
    if (backendTranslation != null) return;
    final source = widget.text;
    final version = _requestVersion;
    final translated = await ref
        .read(garageTranslationServiceProvider)
        .translateToRussian(source);
    if (!mounted || version != _requestVersion) return;
    final normalized = _normalized(translated);
    if (normalized == null || normalized == source.trim()) return;
    setState(() => _runtimeTranslation = normalized);
  }

  @override
  Widget build(BuildContext context) {
    final display =
        _normalized(widget.translatedText) ??
        _runtimeTranslation ??
        widget.text;
    return Text(
      display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _containsChinese(String value) {
  return RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]').hasMatch(value);
}
