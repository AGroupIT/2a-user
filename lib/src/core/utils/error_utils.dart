import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Информация об ошибке для отображения пользователю
class ErrorInfo {
  final String titleRu;
  final String titleZh;
  final String messageRu;
  final String messageZh;
  final IconData icon;

  const ErrorInfo({
    required this.titleRu,
    required this.titleZh,
    required this.messageRu,
    required this.messageZh,
    required this.icon,
  });

  // Для обратной совместимости
  String get title => titleRu;
  String get message => messageRu;

  /// Получить локализованный title
  String getTitle(BuildContext? context) {
    if (context == null) return titleRu;
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'zh' ? titleZh : titleRu;
  }

  /// Получить локализованное message
  String getMessage(BuildContext? context) {
    if (context == null) return messageRu;
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'zh' ? messageZh : messageRu;
  }
}

/// Утилиты для обработки ошибок и преобразования их в понятные сообщения
class ErrorUtils {
  ErrorUtils._();

  /// Получить понятное сообщение об ошибке для пользователя
  static ErrorInfo getErrorInfo(dynamic error) {
    // Обработка DioException
    if (error is DioException) {
      return _handleDioException(error);
    }

    final errorString = error.toString().toLowerCase();

    // Проверка на отсутствие интернета
    if (_isConnectionError(errorString)) {
      return const ErrorInfo(
        titleRu: 'Нет подключения к интернету',
        titleZh: '无网络连接',
        messageRu: 'Проверьте подключение к Wi-Fi или мобильной сети и попробуйте снова.',
        messageZh: '请检查Wi-Fi或移动网络连接，然后重试。',
        icon: Icons.wifi_off_rounded,
      );
    }

    // Проверка на таймаут
    if (_isTimeoutError(errorString)) {
      return const ErrorInfo(
        titleRu: 'Превышено время ожидания',
        titleZh: '连接超时',
        messageRu: 'Сервер не отвечает. Проверьте подключение к интернету или попробуйте позже.',
        messageZh: '服务器未响应。请检查网络连接或稍后重试。',
        icon: Icons.access_time_rounded,
      );
    }

    // Проверка на 401/403
    if (_isAuthError(errorString)) {
      return const ErrorInfo(
        titleRu: 'Ошибка авторизации',
        titleZh: '授权错误',
        messageRu: 'Сессия устарела. Пожалуйста, войдите заново.',
        messageZh: '会话已过期。请重新登录。',
        icon: Icons.lock_outline_rounded,
      );
    }

    // Проверка на 500
    if (_isServerError(errorString)) {
      return const ErrorInfo(
        titleRu: 'Ошибка сервера',
        titleZh: '服务器错误',
        messageRu: 'На сервере произошла ошибка. Попробуйте позже.',
        messageZh: '服务器出现错误。请稍后重试。',
        icon: Icons.cloud_off_rounded,
      );
    }

    // Проверка на 404
    if (_isNotFoundError(errorString)) {
      return const ErrorInfo(
        titleRu: 'Данные не найдены',
        titleZh: '未找到数据',
        messageRu: 'Запрошенные данные не найдены на сервере.',
        messageZh: '在服务器上未找到请求的数据。',
        icon: Icons.search_off_rounded,
      );
    }

    // Общая ошибка
    return const ErrorInfo(
      titleRu: 'Не удалось загрузить данные',
      titleZh: '无法加载数据',
      messageRu: 'Произошла ошибка при загрузке данных. Попробуйте ещё раз.',
      messageZh: '加载数据时出错。请重试。',
      icon: Icons.error_outline_rounded,
    );
  }

  /// Обработка DioException
  static ErrorInfo _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ErrorInfo(
          titleRu: 'Превышено время ожидания',
          titleZh: '连接超时',
          messageRu: 'Сервер не отвечает. Проверьте подключение к интернету или попробуйте позже.',
          messageZh: '服务器未响应。请检查网络连接或稍后重试。',
          icon: Icons.access_time_rounded,
        );

      case DioExceptionType.connectionError:
        return const ErrorInfo(
          titleRu: 'Нет подключения к интернету',
          titleZh: '无网络连接',
          messageRu: 'Проверьте подключение к Wi-Fi или мобильной сети и попробуйте снова.',
          messageZh: '请检查Wi-Fi或移动网络连接，然后重试。',
          icon: Icons.wifi_off_rounded,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return const ErrorInfo(
            titleRu: 'Ошибка авторизации',
            titleZh: '授权错误',
            messageRu: 'Сессия устарела. Пожалуйста, войдите заново.',
            messageZh: '会话已过期。请重新登录。',
            icon: Icons.lock_outline_rounded,
          );
        } else if (statusCode == 404) {
          return const ErrorInfo(
            titleRu: 'Данные не найдены',
            titleZh: '未找到数据',
            messageRu: 'Запрошенные данные не найдены на сервере.',
            messageZh: '在服务器上未找到请求的数据。',
            icon: Icons.search_off_rounded,
          );
        } else if (statusCode != null && statusCode >= 500) {
          return const ErrorInfo(
            titleRu: 'Ошибка сервера',
            titleZh: '服务器错误',
            messageRu: 'На сервере произошла ошибка. Попробуйте позже.',
            messageZh: '服务器出现错误。请稍后重试。',
            icon: Icons.cloud_off_rounded,
          );
        }
        return const ErrorInfo(
          titleRu: 'Ошибка запроса',
          titleZh: '请求错误',
          messageRu: 'Сервер вернул ошибку. Попробуйте позже.',
          messageZh: '服务器返回错误。请稍后重试。',
          icon: Icons.error_outline_rounded,
        );

      case DioExceptionType.cancel:
        return const ErrorInfo(
          titleRu: 'Запрос отменен',
          titleZh: '请求已取消',
          messageRu: 'Запрос был отменен.',
          messageZh: '请求已被取消。',
          icon: Icons.cancel_outlined,
        );

      case DioExceptionType.badCertificate:
        return const ErrorInfo(
          titleRu: 'Ошибка безопасности',
          titleZh: '安全错误',
          messageRu: 'Не удалось проверить сертификат сервера.',
          messageZh: '无法验证服务器证书。',
          icon: Icons.security_outlined,
        );

      case DioExceptionType.unknown:
        // Дополнительная проверка на сетевые ошибки
        final errorMsg = error.message?.toLowerCase() ?? '';
        if (_isConnectionError(errorMsg) || errorMsg.contains('socketexception')) {
          return const ErrorInfo(
            titleRu: 'Нет подключения к интернету',
            titleZh: '无网络连接',
            messageRu: 'Проверьте подключение к Wi-Fi или мобильной сети и попробуйте снова.',
            messageZh: '请检查Wi-Fi или移动网络连接，然后重试。',
            icon: Icons.wifi_off_rounded,
          );
        }

        return const ErrorInfo(
          titleRu: 'Не удалось загрузить данные',
          titleZh: '无法加载数据',
          messageRu: 'Произошла ошибка при загрузке данных. Попробуйте ещё раз.',
          messageZh: '加载数据时出错。请重试。',
          icon: Icons.error_outline_rounded,
        );
    }
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
  static String getShortErrorMessage(dynamic error, [BuildContext? context]) {
    final errorInfo = getErrorInfo(error);
    return errorInfo.getTitle(context);
  }

  /// Получить полное сообщение об ошибке (для диалогов)
  static String getFullErrorMessage(dynamic error, [BuildContext? context]) {
    final errorInfo = getErrorInfo(error);
    return '${errorInfo.getTitle(context)}\n\n${errorInfo.getMessage(context)}';
  }

  /// Проверить, является ли ошибка сетевой (нет интернета)
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    final errorString = error.toString().toLowerCase();
    return _isConnectionError(errorString) || _isTimeoutError(errorString);
  }
}
