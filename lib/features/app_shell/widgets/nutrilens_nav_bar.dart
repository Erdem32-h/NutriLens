import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Custom bottom navigation:
///   [meals] [history] [SCANNER (big, center)] [favorites] [profile]
///
/// The scanner button is intentionally larger than the other tabs and lifts
/// above the bar so the primary action of the app stays unmistakable. When
/// the scanner tab is active, a subtle scanning-line animation runs inside
/// the button to mirror the live camera viewfinder.
class NutriLensNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String mealsLabel;
  final String historyLabel;
  final String scannerLabel;
  final String favoritesLabel;
  final String profileLabel;

  const NutriLensNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.mealsLabel,
    required this.historyLabel,
    required this.scannerLabel,
    required this.favoritesLabel,
    required this.profileLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Background bar
            Positioned.fill(
              top: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(color: colors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideTab(
                        icon: Icons.restaurant_menu_outlined,
                        selectedIcon: Icons.restaurant_menu,
                        label: mealsLabel,
                        selected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    Expanded(
                      child: _SideTab(
                        icon: Icons.history_outlined,
                        selectedIcon: Icons.history,
                        label: historyLabel,
                        selected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                    // Reserve space for the centered scanner button.
                    const SizedBox(width: 80),
                    Expanded(
                      child: _SideTab(
                        icon: Icons.favorite_outline,
                        selectedIcon: Icons.favorite,
                        label: favoritesLabel,
                        selected: currentIndex == 3,
                        onTap: () => onTap(3),
                      ),
                    ),
                    Expanded(
                      child: _SideTab(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: profileLabel,
                        selected: currentIndex == 4,
                        onTap: () => onTap(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Center scanner button (lifts above the bar)
            Positioned(
              bottom: 24,
              child: _ScannerButton(
                active: currentIndex == 2,
                label: scannerLabel,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.primary : colors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                fontFamilyFallback: const ['Roboto', 'sans-serif'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerButton extends StatefulWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;

  const _ScannerButton({
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ScannerButton> createState() => _ScannerButtonState();
}

class _ScannerButtonState extends State<_ScannerButton>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scanController, _pulseController]),
              builder: (context, _) {
                final pulse = math.sin(_pulseController.value * math.pi * 2);
                final glow = (0.18 + 0.12 * (pulse + 1) / 2).clamp(0.18, 0.30);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring (always running, subtler when inactive)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary
                            .withValues(alpha: widget.active ? glow : 0.12),
                      ),
                    ),
                    // Scanner button core
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: colors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color:
                                colors.primary.withValues(alpha: 0.40),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    // Viewfinder corners + scanning line — gives the
                    // "tarama yapıyor" feel without blocking the icon.
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: ClipOval(
                        child: CustomPaint(
                          painter: _ViewfinderPainter(
                            scan: _scanController.value,
                            color: Colors.white.withValues(alpha: 0.85),
                            active: widget.active,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: widget.active ? FontWeight.w800 : FontWeight.w600,
              color: widget.active ? colors.primary : colors.textSecondary,
              fontFamilyFallback: const ['Roboto', 'sans-serif'],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final double scan; // 0..1
  final Color color;
  final bool active;

  _ViewfinderPainter({
    required this.scan,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Paint()
      ..color = color.withValues(alpha: active ? 1.0 : 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLen = size.width * 0.20;
    final inset = size.width * 0.22;

    // Four L-shaped viewfinder corners
    void drawCorner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(cornerLen * dx, 0), corner);
      canvas.drawLine(origin, origin.translate(0, cornerLen * dy), corner);
    }

    drawCorner(Offset(inset, inset), 1, 1);
    drawCorner(Offset(size.width - inset, inset), -1, 1);
    drawCorner(Offset(inset, size.height - inset), 1, -1);
    drawCorner(Offset(size.width - inset, size.height - inset), -1, -1);

    // Animated scan line — y oscillates between insets
    final top = inset;
    final bottom = size.height - inset;
    final y = top + (bottom - top) * scan;
    final scanPaint = Paint()
      ..color = color.withValues(alpha: active ? 0.90 : 0.45)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(inset + 2, y), Offset(size.width - inset - 2, y),
        scanPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) {
    return oldDelegate.scan != scan ||
        oldDelegate.active != active ||
        oldDelegate.color != color;
  }
}
