
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/widgets/widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const showIntro = false;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color neonGreen = Color(0xFF9DFF1E);

  late final AnimationController _controller;

  bool _showActions = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      _decide();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decide() {
    if (!mounted) return;

    if (ref.read(onboardedProvider)) {
      context.go('/home');
      return;
    }

    setState(() => _showActions = true);
  }

  Future<void> _go(String mode) async {
    await ref.read(onboardedProvider.notifier).complete();

    if (ref.read(selectedRegionProvider) == null) {
      await ref.read(selectedRegionProvider.notifier).select('kerala');
    }

    if (!mounted) return;

    if (mode == 'login') {
      context.go('/auth?mode=login&redirect=%2Fhome');
    } else if (SplashScreen.showIntro) {
      context.go('/intro');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final logoProgress = Curves.easeOutCubic.transform(
              (_controller.value / 0.72).clamp(0.0, 1.0),
            );

            final taglineOpacity = Curves.easeOut.transform(
              ((_controller.value - 0.72) / 0.28).clamp(0.0, 1.0),
            );

            return Stack(
              children: [
                // CENTRED WORDMARK AND TAGLINE
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 340,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            const Text(
                              'TrailSeek',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: 'GreatVibes',
                                fontSize: 82,
                                color: Colors.transparent,
                                height: 1.3,
                              ),
                            ),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: logoProgress,
                                child: const Text(
                                  'TrailSeek',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontFamily: 'GreatVibes',
                                    fontSize: 82,
                                    fontWeight: FontWeight.normal,
                                    color: neonGreen,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // TAGLINE
                      Opacity(
                        opacity: taglineOpacity,
                        child: const Text(
                          'EXPLORE WITHOUT LIMITS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // BOTTOM ACTIONS
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: AnimatedOpacity(
                    opacity: _showActions ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: IgnorePointer(
                      ignoring: !_showActions,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NeonButton(
                            label: 'Get Started',
                            onPressed: () => _go('signup'),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _go('login'),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: neonGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
