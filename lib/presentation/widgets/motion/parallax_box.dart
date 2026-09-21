import 'package:flutter/material.dart';

/// Frames [child] so that it slides inside its box as the list scrolls: the
/// picture travels a little slower than the card, which gives photos depth.
///
/// Outside a scrollable, or under reduced motion, it is just an aspect-ratio
/// box.
class ParallaxBox extends StatelessWidget {
  const ParallaxBox({
    super.key,
    required this.child,
    this.aspectRatio = 16 / 9,
    this.extra = 0.28,
  });

  final Widget child;
  final double aspectRatio;

  /// How much taller than its frame the child is drawn, i.e. the travel.
  final double extra;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || MediaQuery.disableAnimationsOf(context)) {
      return AspectRatio(aspectRatio: aspectRatio, child: child);
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(builder: (context, constraints) {
        final childSize = Size(
          constraints.maxWidth,
          constraints.maxHeight * (1 + extra),
        );
        return ClipRect(
          child: Flow(
            delegate: _ParallaxDelegate(
              scrollable: scrollable,
              itemContext: context,
              childSize: childSize,
            ),
            children: [
              SizedBox(
                  width: childSize.width,
                  height: childSize.height,
                  child: child),
            ],
          ),
        );
      }),
    );
  }
}

class _ParallaxDelegate extends FlowDelegate {
  _ParallaxDelegate({
    required this.scrollable,
    required this.itemContext,
    required this.childSize,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext itemContext;
  final Size childSize;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(childSize);

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollBox = scrollable.context.findRenderObject() as RenderBox?;
    final itemBox = itemContext.findRenderObject() as RenderBox?;
    if (scrollBox == null || itemBox == null || !itemBox.attached) {
      context.paintChild(0);
      return;
    }
    // Where the middle of the card sits in the viewport, 0 (top) .. 1 (bottom).
    final offset = itemBox.localToGlobal(
      itemBox.size.centerLeft(Offset.zero),
      ancestor: scrollBox,
    );
    final viewport = scrollable.position.viewportDimension;
    final fraction = (offset.dy / viewport).clamp(0.0, 1.0);
    final alignment = Alignment(0, fraction * 2 - 1);
    final rect = alignment.inscribe(childSize, Offset.zero & context.size);
    context.paintChild(0, transform: Matrix4.translationValues(0, rect.top, 0));
  }

  @override
  bool shouldRepaint(covariant _ParallaxDelegate old) =>
      old.scrollable != scrollable ||
      old.itemContext != itemContext ||
      old.childSize != childSize;
}
