// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';

/// Custom page route with smooth slide transition
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final AxisDirection direction;
  final Duration duration;

  SlidePageRoute({
    required this.child,
    this.direction = AxisDirection.right,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset begin;
            switch (direction) {
              case AxisDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case AxisDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
              case AxisDirection.left:
                begin = const Offset(1.0, 0.0);
                break;
              case AxisDirection.right:
                begin = const Offset(-1.0, 0.0);
                break;
            }

            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}

/// Custom page route with fade transition
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  FadePageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        );
}

/// Custom page route with scale transition
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  ScalePageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: CurveTween(curve: Curves.easeInOutBack).animate(animation),
              child: child,
            );
          },
        );
}

/// Animated container with smooth transitions
class AnimatedModernContainer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool animate;

  const AnimatedModernContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.animate = true,
  });

  @override
  _AnimatedModernContainerState createState() => _AnimatedModernContainerState();
}

class _AnimatedModernContainerState extends State<AnimatedModernContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return AnimatedContainer(
        duration: widget.duration,
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.white,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
          boxShadow: widget.boxShadow ?? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: AnimatedContainer(
              duration: widget.duration,
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              margin: widget.margin,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
                boxShadow: widget.boxShadow ?? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Staggered animation for lists
class StaggeredListAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration delay;
  final Axis direction;

  const StaggeredListAnimation({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
    this.delay = const Duration(milliseconds: 100),
    this.direction = Axis.vertical,
  });

  @override
  _StaggeredListAnimationState createState() => _StaggeredListAnimationState();
}

class _StaggeredListAnimationState extends State<StaggeredListAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: widget.duration,
        vsync: this,
      ),
    );

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: widget.direction == Axis.vertical
            ? const Offset(0, 0.5)
            : const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(Duration(milliseconds: widget.delay.inMilliseconds * i ~/ 2));
      if (mounted) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.children.length, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimations[index],
              child: FadeTransition(
                opacity: _fadeAnimations[index],
                child: widget.children[index],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Animated button with hover and tap effects
class AnimatedModernButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Duration duration;

  const AnimatedModernButton({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = const Color(0xFF4CAF50),
    this.hoverColor,
    this.borderRadius,
    this.padding,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  _AnimatedModernButtonState createState() => _AnimatedModernButtonState();
}

class _AnimatedModernButtonState extends State<AnimatedModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: widget.duration,
              padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _isPressed 
                    ? (widget.hoverColor ?? widget.backgroundColor.withOpacity(0.8))
                    : widget.backgroundColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
                boxShadow: _isPressed ? [] : [
                  BoxShadow(
                    color: widget.backgroundColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Hero animation wrapper for smooth transitions
class ModernHero extends StatelessWidget {
  final String tag;
  final Widget child;
  final Duration? flightDuration;

  const ModernHero({
    super.key,
    required this.tag,
    required this.child,
    this.flightDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (animation.value * 0.1),
              child: Opacity(
                opacity: 1.0 - (animation.value * 0.1),
                child: Material(
                  color: Colors.transparent,
                  child: toHeroContext.widget,
                ),
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}

/// Navigation helper with animated transitions
class AnimatedNavigator {
  static Future<T?> slideToPage<T>(
    BuildContext context,
    Widget page, {
    AxisDirection direction = AxisDirection.right,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      SlidePageRoute<T>(
        child: page,
        direction: direction,
        duration: duration,
      ),
    );
  }

  static Future<T?> fadeToPage<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return Navigator.of(context).push<T>(
      FadePageRoute<T>(
        child: page,
        duration: duration,
      ),
    );
  }

  static Future<T?> scaleToPage<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      ScalePageRoute<T>(
        child: page,
        duration: duration,
      ),
    );
  }
}
