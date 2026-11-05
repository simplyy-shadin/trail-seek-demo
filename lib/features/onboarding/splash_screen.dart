
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
      duration: const Duration(milliseconds: 1600),
    );

    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
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
            // Smooth left-to-right wordmark reveal.
            final logoProgress = Curves.easeInOutCubic.transform(
              (_controller.value / 0.72).clamp(0.0, 1.0),
            );

            const logo = 'TrailSeek';

            final visibleCharacters =
                (logo.length * logoProgress).floor();

            final visibleText =
                logo.substring(0, visibleCharacters);

            // Tagline fades in after the wordmark.
            final taglineOpacity = Curves.easeOut.transform(
              ((_controller.value - 0.72) / 0.28)
                  .clamp(0.0, 1.0),
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 4),

                  // TRAILSEEK WORDMARK
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      visibleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'GreatVibes',
                        fontSize: 82,
                        fontWeight: FontWeight.normal,
                        color: neonGreen,
                        height: 1.3,
                      ),
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

                  const Spacer(flex: 4),

                  // EXISTING ACTIONS
                  AnimatedOpacity(
                    opacity: _showActions ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: IgnorePointer(
                      ignoring: !_showActions,
                      child: Column(
                        children: [
                          NeonButton(
                            label: 'Get Started',
                            onPressed: () => _go('signup'),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
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

                  if (!_showActions)
                    const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
