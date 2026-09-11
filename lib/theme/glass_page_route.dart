import 'package:flutter/material.dart';

import '../widgets/glass_container.dart';

/// A fade route with a stable themed surface behind its page content.
class GlassPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration fadeDuration;
  final bool isOpaque;

  GlassPageRoute({
    required this.builder,
    super.settings,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.isOpaque = false,
  });

  @override
  bool get opaque => isOpaque;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => fadeDuration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Container(
      color: stableSurfaceColor(context),
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
