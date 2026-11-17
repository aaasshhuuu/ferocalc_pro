import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingShimmer extends StatelessWidget {

  const LoadingShimmer({
    Key? key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 12.0,
  }) : super(key: key);
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (prefersReducedMotion) {
      return Semantics(
        label: 'Loading content',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Loading content',
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surface,
        highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
