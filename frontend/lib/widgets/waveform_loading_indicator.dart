import 'package:flutter/material.dart';
import 'dart:math';

/// Waveform loading indicator for production analysis states
class WaveformLoadingIndicator extends StatefulWidget {
  final String label;

  const WaveformLoadingIndicator({super.key, this.label = 'Analyzing...'});

  @override
  State<WaveformLoadingIndicator> createState() => _WaveformLoadingIndicatorState();
}

class _WaveformLoadingIndicatorState extends State<WaveformLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(12, (index) {
                  final height = (sin(_controller.value * 2 * pi + index * 0.5) + 1.2) * 15;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 4,
                    height: height,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
