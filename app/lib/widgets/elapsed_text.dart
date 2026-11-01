import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ui/format.dart';

/// "12:34" since [since], ticking on its own exactly at each whole second.
///
/// Not recomputed from status updates: those arrive about once a second but
/// with jitter, and sampling a clock at 1 Hz near the second boundary shows
/// 00:00, 00:02, 00:02 — the timer seems to hang and then jump.
class ElapsedText extends StatefulWidget {
  const ElapsedText({super.key, required this.since, this.style, this.now = DateTime.now});

  final DateTime since;
  final TextStyle? style;

  /// The clock, swappable in tests.
  final DateTime Function() now;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Timer? _timer;

  Duration get _elapsed {
    final d = widget.now().difference(widget.since);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ElapsedText old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) _schedule();
  }

  /// Wakes up right after the next whole second of elapsed time, so the
  /// display changes once per second, on time, never twice or not at all.
  void _schedule() {
    _timer?.cancel();
    final intoSecond = _elapsed.inMicroseconds % Duration.microsecondsPerSecond;
    final wait = Duration(microseconds: Duration.microsecondsPerSecond - intoSecond + 1000);
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(elapsed(_elapsed), style: widget.style);
}
