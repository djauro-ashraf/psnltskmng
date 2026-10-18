import 'package:flutter/material.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';

/// The letter of an operation (M, R, L) as a tile. Letters are domain terms.
/// M is the strong tile (it adds something new); R and L are quieter.
class OpTile extends StatelessWidget {
  const OpTile({super.key, required this.operation, this.size = 40});

  final Operation operation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fill, onFill) = switch (operation) {
      Operation.m => (scheme.primary, scheme.onPrimary),
      Operation.r => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      Operation.l => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        operation.letter,
        style: theme.textTheme.titleLarge?.copyWith(
          color: onFill,
          fontSize: size * 0.5,
          height: 1,
        ),
      ),
    );
  }
}
