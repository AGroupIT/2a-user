import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase для push-уведомлений
  await PushNotificationService.initializeFirebase();
  
  runApp(const ProviderScope(child: App()));
}
