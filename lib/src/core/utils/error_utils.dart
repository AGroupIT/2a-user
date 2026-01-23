import 'package:flutter/material.dart';

/// Информация об ошибке для отображения пользователю
class ErrorInfo {
  final String title;
  final String message;
  final IconData icon;

  const ErrorInfo({
    required this.title,
    required this.message,
    required this.icon,
  });
}

/// Утилиты для обработки ошибок и преобразования их в понятные сообщения
class ErrorUtils {
  ErrorUtils._();

  /// Получить понятное сообщение об ошибке для пользователя
  static ErrorInfo getErrorInfo(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Проверка на отсутствие интернета
    if (_isConnectionError(errorString)) {
      return const ErrorInfo(
        title: 'Нет подключения к интернету',
        message:
            'Проверьте подключение к Wi-Fi или мобильной сети и попробуйте снова.',
        icon: Icons.wifi_off_rounded,
      );
    }

    // Проверка на таймаут
    if (_isTimeoutError(errorString)) {
      return const ErrorInfo(
        title: 'Превышено время ожидания',
        message:
            'Сервер не отвечает. Проверьте подключение к интернету или попробуйте позже.',
        icon: Icons.access_time_rounded,
      );
    }

    // Проверка на 401/403
    if (_isAuthError(errorString)) {
      return const ErrorInfo(
        title: 'Ошибка авторизации',
        message: 'Сессия устарела. Пожалуйста, войдите заново.',
        icon: Icons.lock_outline_rounded,
      );
    }

    // Проверка на 500
    if (_isServerError(errorString)) {
      return const ErrorInfo(
        title: 'Ошибка сервера',
        message: 'На сервере произошла ошибка. Попробуйте позже.',
        icon: Icons.cloud_off_rounded,
      );
    }

    // Проверка на 404
    if (_isNotFoundError(errorString)) {
      return const ErrorInfo(
        title: 'Данные не найдены',
        message: 'Запрошенные данные не найдены на сервере.',
        icon: Icons.search_off_rounded,
      );
    }

    // Общая ошибка
    return const ErrorInfo(
      title: 'Не удалось загрузить данные',
      message: 'Произошла ошибка при загрузке данных. Попробуйте ещё раз.',
      icon: Icons.error_outline_rounded,
    );
  }

  /// Проверка на ошибку подключения
  static bool _isConnectionError(String error) {
    return error.contains('failed host lookup') ||
        error.contains('connection error') ||
        error.contains('connection errored') ||
        error.contains('no address associated with hostname') ||
        error.contains('socketexception') ||
        error.contains('network is unreachable') ||
        error.contains('connection refused') ||
        error.contains('connection reset') ||
        error.contains('connection closed') ||
        error.contains('no internet') ||
        error.contains('network error');
  }

  /// Проверка на ошибку таймаута
  static bool _isTimeoutError(String error) {
    return error.contains('timeout') ||
        error.contains('timed out') ||
        error.contains('deadline exceeded');
  }

  /// Проверка на ошибку авторизации
  static bool _isAuthError(String error) {
    return error.contains('401') ||
        error.contains('403') ||
        error.contains('unauthorized') ||
        error.contains('forbidden') ||
        error.contains('authentication failed') ||
        error.contains('access denied');
  }

  /// Проверка на ошибку сервера
  static bool _isServerError(String error) {
    return error.contains('500') ||
        error.contains('502') ||
        error.contains('503') ||
        error.contains('504') ||
        error.contains('internal server error') ||
        error.contains('bad gateway') ||
        error.contains('service unavailable') ||
        error.contains('gateway timeout');
  }

  /// Проверка на ошибку "не найдено"
  static bool _isNotFoundError(String error) {
    return error.contains('404') || error.contains('not found');
  }

  /// Получить краткое сообщение об ошибке (для SnackBar)
  static String getShortErrorMessage(dynamic error) {
    final errorInfo = getErrorInfo(error);
    return errorInfo.title;
  }

  /// Получить полное сообщение об ошибке (для диалогов)
  static String getFullErrorMessage(dynamic error) {
    final errorInfo = getErrorInfo(error);
    return '${errorInfo.title}\n\n${errorInfo.message}';
  }
}
