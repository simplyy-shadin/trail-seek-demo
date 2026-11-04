import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

/// Frame 1. Browse-first: nobody is asked to sign in here. Returning users
/// go straight to Home; first-time users pick a region. Login appears only
/// when a gated action is taken (start a trek, plan or join a group, post).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// The old three-slide intro is kept behind this flag; the mockup goes
  /// straight from the splash to sign-up.
  static const showIntro = false;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), _decide);
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
    // Kerala is the launch region; other regions are picked later in Profile.
    if (ref.read(selectedRegionProvider) == null) await ref.read(selectedRegionProvider.notifier).select('kerala');
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CoverArt(hue: 150),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.45, 1],
                colors: [TsColors.scrim, Colors.transparent, TsColors.bg],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/images/logo.jpeg', width: 112, height: 112, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    text: const TextSpan(
                      style: TsText.display,
                      children: [
                        TextSpan(text: 'Trail ', style: TextStyle(color: TsColors.textPrimary)),
                        TextSpan(text: 'Seek', style: TextStyle(color: TsColors.neon)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Explore · Track · Earn', style: TextStyle(fontSize: 13, letterSpacing: 1.5, color: TsColors.textMuted, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _showActions ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: IgnorePointer(
                      ignoring: !_showActions,
                      child: Column(
                        children: [
                          NeonButton(label: 'Get Started', onPressed: () => _go('signup')),
                          const SizedBox(height: 14),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Already have an account? ', style: TsText.caption),
                              GestureDetector(
                                onTap: () => _go('login'),
                                child: const Text('Log in', style: TextStyle(color: TsColors.neon, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_showActions)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
