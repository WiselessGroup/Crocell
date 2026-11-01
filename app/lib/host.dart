import 'dart:io';

/// How this copy of Crocell got onto this machine. Decides how it updates
/// and how its service gets installed.
enum HostKind {
  /// A Linux AppImage, usually kept by Gear Lever.
  appImage,

  /// Linux built from source or packaged some other way.
  linux,
  windows,
  macos,
  android,
  other,
}

class Host {
  const Host(this.kind, {this.appImagePath = ''});

  final HostKind kind;

  /// Where the AppImage lives, for the service install command.
  final String appImagePath;

  /// This machine. [os] and [env] are for tests.
  factory Host.detect({String? os, Map<String, String>? env}) {
    env ??= Platform.environment;
    switch (os ?? Platform.operatingSystem) {
      case 'linux':
        final image = env['APPIMAGE'] ?? '';
        return image.isEmpty ? const Host(HostKind.linux) : Host(HostKind.appImage, appImagePath: image);
      case 'windows':
        return const Host(HostKind.windows);
      case 'macos':
        return const Host(HostKind.macos);
      case 'android':
        return const Host(HostKind.android);
    }
    return const Host(HostKind.other);
  }

  /// The core runs inside the app here, so there is no service to install
  /// or to fall out of date.
  bool get embeddedCore => kind == HostKind.android;
}
