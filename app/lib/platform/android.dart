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

/// "Hide the notification" (Android). Off until the person turns it on.
Future<bool> hideVpnNotification() async => await androidCore.invokeMethod<bool>('hideNotification') ?? false;

/// Turning it on also brings up Android's "don't restrict in the
/// background" request.
Future<void> setHideVpnNotification(bool hide) => androidCore.invokeMethod<void>('setHideNotification', hide);

/// Android's own "Always-on VPN" page, where blocking without a VPN is turned
/// on. An app can't do that for itself.
Future<void> openVpnSettings() => androidCore.invokeMethod<void>('openVpnSettings');

/// Whether Android blocks connections without the VPN. Null while the VPN is
/// off: the system only tells a running VPN service.
Future<bool?> vpnLockdown() => androidCore.invokeMethod<bool>('vpnLockdown');
