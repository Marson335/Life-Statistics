import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';

const MethodChannel methodeChannel =
    MethodChannel('x-slayer/notifications_channel');
const EventChannel _eventChannel = EventChannel('x-slayer/notifications_event');
Stream<ServiceNotificationEvent>? _stream;

class NotificationListenerService {
  NotificationListenerService._();

  /// stream the incoming notifications events
  static Stream<ServiceNotificationEvent> get notificationsStream {
    if (Platform.isAndroid) {
      _stream ??=
          _eventChannel.receiveBroadcastStream().map<ServiceNotificationEvent>(
                (event) => ServiceNotificationEvent.fromMap(event),
              );
      return _stream!;
    }
    throw Exception("Notifications API exclusively available on Android!");
  }

  /// request notification permission
  /// it will open the notification settings page and return `true` once the permission granted.
  static Future<bool> requestPermission() async {
    try {
      final result = await methodeChannel.invokeMethod('requestPermission');
      return result ?? false;
    } on PlatformException catch (error) {
      log("$error");
      return Future.value(false);
    }
  }

  /// check if notification permission is enebaled
  static Future<bool> isPermissionGranted() async {
    try {
      return await methodeChannel.invokeMethod('isPermissionGranted');
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  /// get currently active notifications
  static Future<List<ServiceNotificationEvent>> getActiveNotifications() async {
    try {
      final List<dynamic> result =
          await methodeChannel.invokeMethod('getActiveNotifications');
      return result
          .map((item) => ServiceNotificationEvent.fromMap(item))
          .toList();
    } on PlatformException catch (error) {
      log("getActiveNotifications error: $error");
      return [];
    }
  }

  /// get pending notifications saved in background native queue
  static Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    try {
      final String? jsonStr =
          await methodeChannel.invokeMethod<String>('getPendingNotifications');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (error) {
      log("getPendingNotifications error: $error");
      return [];
    }
  }

  /// clear the pending native notifications queue
  static Future<void> clearPendingNotifications() async {
    try {
      await methodeChannel.invokeMethod('clearPendingNotifications');
    } catch (error) {
      log("clearPendingNotifications error: $error");
    }
  }
}
