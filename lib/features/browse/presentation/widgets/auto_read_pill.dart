import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// Floating capsule pill for auto-read controls (play/pause, -/+ 10 WPM, pace label).
class AutoReadPill extends ConsumerStatefulWidget {
  const AutoReadPill({
    super.key,
    this.onTapPace,
  });

  /// Called when user taps the WPM text label (e.g. to open reading options).
  final VoidCallback? onTapPace;

  @override
  ConsumerState<AutoReadPill> createState() => _AutoReadPillState();
}

class _AutoReadPillState extends ConsumerState<AutoReadPill> {
  Timer? _dimTimer;
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    _resetDimTimer();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    super.dispose();
  }

  void _resetDimTimer() {
    _dimTimer?.cancel();
    if (_dimmed && mounted) {
      setState(() => _dimmed = false);
    }
    final playing = ref.read(autoReadProvider).playing;
    if (playing) {
      _dimTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && ref.read(autoReadProvider).playing) {
          setState(() => _dimmed = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      autoReadProvider.select((s) => s.playing),
      (prev, next) {
        _resetDimTimer();
      },
    );

    final autoRead = ref.watch(autoReadProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final wpm = autoRead.wordsPerMinute.round();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _resetDimTimer();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _dimmed ? 0.35 : 1.0,
        child: Material(
          elevation: 3,
          shadowColor: Colors.black26,
          color: scheme.surfaceContainerHigh,
          shape: StadiumBorder(
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: autoRead.playing
                      ? l10n.autoReadPause
                      : l10n.autoReadPlay,
                  icon: Icon(
                    autoRead.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: autoRead.playing
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _resetDimTimer();
                    ref.read(autoReadProvider.notifier).togglePlaying();
                  },
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: '-10 WPM',
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: autoRead.wordsPerMinute <= ReadingPacer.minWpm
                      ? null
                      : () {
                          _resetDimTimer();
                          ref
                              .read(autoReadProvider.notifier)
                              .adjustWpm(-ReadingPacer.stepWpm);
                        },
                ),
                InkWell(
                  onTap: widget.onTapPace ?? _resetDimTimer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '$wpm WPM',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: '+10 WPM',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: autoRead.wordsPerMinute >= ReadingPacer.maxWpm
                      ? null
                      : () {
                          _resetDimTimer();
                          ref
                              .read(autoReadProvider.notifier)
                              .adjustWpm(ReadingPacer.stepWpm);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

