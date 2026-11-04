
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class TsNavItem {
  const TsNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class TsBottomNav extends StatefulWidget {
  const TsBottomNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<TsNavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  static const defaultItems = [
    TsNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    TsNavItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
    ),
    TsNavItem(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      label: 'Map',
    ),
    TsNavItem(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
      label: 'Profile',
    ),
  ];

  @override
  State<TsBottomNav> createState() => _TsBottomNavState();
}

class _TsBottomNavState extends State<TsBottomNav> {
  double? _dragIndex;

  double _indexFromPosition(double x, double width) {
    final count = widget.items.length;
    if (count <= 1 || width <= 0) return 0;

    return ((x / width) * count - 0.5)
        .clamp(0.0, (count - 1).toDouble());
  }

  void _updateDrag(double x, double width) {
    setState(() {
      _dragIndex = _indexFromPosition(x, width);
    });
  }

  void _finishDrag() {
    if (_dragIndex == null) return;

    final index = _dragIndex!.round().clamp(
      0,
      widget.items.length - 1,
    );

    setState(() => _dragIndex = null);
    widget.onSelected(index);
  }

  void _cancelDrag() {
    setState(() => _dragIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final activePosition = _dragIndex ?? widget.selected.toDouble();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 68,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tabWidth = width / widget.items.length;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final index = _indexFromPosition(
                      details.localPosition.dx,
                      width,
                    ).round();
                    widget.onSelected(index);
                  },
                  onHorizontalDragStart: (details) {
                    _updateDrag(details.localPosition.dx, width);
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateDrag(details.localPosition.dx, width);
                  },
                  onHorizontalDragEnd: (_) => _finishDrag(),
                  onHorizontalDragCancel: _cancelDrag,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.08),
                          blurRadius: 10,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 24,
                          sigmaY: 24,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.20),
                                 const Color(0xFF252A27).withValues(alpha: 0.58),
                                 const Color(0xFF151A17).withValues(alpha: 0.72),
                                 const Color(0xFF080B09).withValues(alpha: 0.82),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Top glass reflection.
                              Positioned(
                                top: 0,
                                left: 35,
                                right: 35,
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Soft moving glass highlight.
                              AnimatedPositioned(
                                duration: _dragIndex != null
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                left: tabWidth * activePosition +
                                    (tabWidth - 46) / 2,
                                top: 7,
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        TsColors.neon.withValues(alpha: 0.22),
                                        TsColors.neon.withValues(alpha: 0.07),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Row(
                                children: List.generate(
                                  widget.items.length,
                                  (i) {
                                    final distance =
                                        (activePosition - i).abs();
                                    final intensity =
                                        (1.0 - distance).clamp(0.0, 1.0);

                                    final color = Color.lerp(
                                      Colors.white.withValues(alpha: 0.68),
                                      TsColors.neon,
                                      intensity,
                                    )!;

                                    return Expanded(
                                      child: Center(
                                        child: Transform.scale(
                                          scale: 1 + intensity * 0.13,
                                          child: Icon(
                                            intensity > 0.65
                                                ? widget.items[i].selectedIcon
                                                : widget.items[i].icon,
                                            size: 24,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
