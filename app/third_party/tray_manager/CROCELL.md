# tray_manager in Crocell

A copy of [tray_manager](https://pub.dev/packages/tray_manager) 0.5.3, MIT, see `LICENSE`.

From pub.dev the plugin also builds for Linux, and there it needs
`libayatana-appindicator` both to build and to run. Crocell has no tray icon on
Linux, so that would be a dependency for nothing, in the AppImage too. Plugins
can't be turned off per platform, which leaves a copy without `linux/`.

Versions from 0.6 on moved to the experimental `nativeapi`, which is why this
one stays on 0.5.

| Change | Why |
|---|---|
| removed `linux/`, `example/`, `test/` and the Linux platform in `pubspec.yaml` | see above |
