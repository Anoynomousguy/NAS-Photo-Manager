import 'package:flutter/material.dart';

/// A quiet pulse that keeps loading surfaces alive without a spinner's
/// stop-and-start rhythm. The animation is disposed with the skeleton, so it
/// never keeps a completed page alive.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.48, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = 7,
    this.color,
  });

  final double height;
  final double width;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shell-level skeleton shown while a module is being revealed. It mirrors the
/// app's header and content rhythm so the transition feels intentional rather
/// than like an empty flash.
class ModuleSkeleton extends StatelessWidget {
  const ModuleSkeleton({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Semantics(
      label: 'Opening $title',
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surface,
          child: SkeletonPulse(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const SkeletonBlock(
                          width: 34,
                          height: 34,
                          radius: 17,
                        ),
                        const SizedBox(width: 12),
                        const SkeletonBlock(width: 116, height: 12),
                        const Spacer(),
                        SkeletonBlock(
                          width: 82,
                          height: 34,
                          radius: 17,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const SkeletonBlock(width: 174, height: 26),
                    const SizedBox(height: 10),
                    const SkeletonBlock(width: 252, height: 12),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: SkeletonBlock(height: 92, radius: 12),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SkeletonBlock(
                            height: 92,
                            radius: 12,
                            color: scheme.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    for (int index = 0; index < 5; index++) ...<Widget>[
                      Row(
                        children: <Widget>[
                          const SkeletonBlock(
                            width: 40,
                            height: 40,
                            radius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SkeletonBlock(
                                  width: index.isEven ? 190 : 235,
                                  height: 12,
                                ),
                                const SizedBox(height: 7),
                                const SkeletonBlock(width: 122, height: 9),
                              ],
                            ),
                          ),
                          const SkeletonBlock(width: 24, height: 24),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
