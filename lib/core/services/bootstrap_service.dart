import 'package:hive_flutter/hive_flutter.dart';

import 'notification_service.dart';

class BootstrapService {
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await NotificationService.instance.initialize();
  }
}