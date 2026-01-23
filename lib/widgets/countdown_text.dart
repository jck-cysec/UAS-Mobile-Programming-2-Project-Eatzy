import 'dart:async';

import 'package:flutter/material.dart';

/// A small widget that counts down towards [target].
/// Displays a human-friendly string in Indonesian and updates every second.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final String readyText;
  final DateTime Function()? nowProvider; // for testing

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.readyText = 'Siap',
    this.nowProvider,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  void _updateRemaining() {
    setState(() {
      _remaining = widget.target.difference(_now());
    });
  }

  void _onTick() {
    _updateRemaining();
    if (_remaining.inSeconds <= 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(covariant CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _timer?.cancel();
      _updateRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.inSeconds <= 0) return widget.readyText;

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) return '$hours jam $minutes menit';
    if (minutes > 0) return '$minutes menit $seconds detik';
    return '$seconds detik';
  }

  @override
  Widget build(BuildContext context) {
    return Text(_format(_remaining), style: widget.style);
  }
}
