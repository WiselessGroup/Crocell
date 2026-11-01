/// What the app itself went through: errors it showed, failed checks.
/// Copied together with the core's log, so a report has both halves.
final _lines = <String>[];
const _max = 300;

void appLog(String line) {
  final now = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
  _lines.add('$now app: $line');
  if (_lines.length > _max) _lines.removeRange(0, _lines.length - _max);
}

String appLogText() => _lines.join('\n');
