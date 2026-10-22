// Author: Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends a text message from this phone. Android sends it straight away
/// (with the SMS permission); iOS doesn't allow that, so Messages opens with
/// the text filled in for the patient to send.
class SmsSender {
  const SmsSender();

  static const MethodChannel _channel = MethodChannel('libucare/sms');

  /// Asks for the SMS permission now, so the first missed dose doesn't.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// True when the message was sent, or (iOS) handed to Messages.
  Future<bool> send({required String phone, required String message}) async {
    if (Platform.isAndroid) {
      try {
        if (!await requestPermission()) return false;
        return await _channel.invokeMethod<bool>('send', <String, String>{
              'phone': phone,
              'message': message,
            }) ??
            false;
      } on PlatformException {
        return false;
      }
    }
    final Uri uri = Uri(
      scheme: 'sms',
      path: phone,
      query: 'body=${Uri.encodeComponent(message)}',
    );
    try {
      return await launchUrl(uri);
    } on Object {
      return false;
    }
  }
}

final Provider<SmsSender> smsSenderProvider = Provider<SmsSender>(
  (Ref ref) => const SmsSender(),
);
