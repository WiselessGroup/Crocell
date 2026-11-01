import 'dart:io';

import 'package:flutter/services.dart';

/// The Android side of the app: where the embedded core listens, and the
/// system's VPN permission.
const androidCore = MethodChannel('crocell/core');

/// Asks Android for permission to run a VPN, once: after the first yes the
/// dialog never shows again. True everywhere else.
Future<bool> ensureVpnPermission() async {
  if (!Platform.isAndroid) return true;
  return await androidCore.invokeMethod<bool>('prepareVpn') ?? false;
}
