import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fotoğrafın üzerinde yukarıdan aşağı süpüren tarama çizgisi.
///
/// `FoodResultScreen`'den çıkarıldı: onboarding, analiz ekranının kullandığı
/// animasyonun aynısını göstersin diye. Ayrı bir "onboarding animasyonu"
/// yazmak ikisini zamanla birbirinden uzaklaştırırdı.
///
/// [sweeps] animasyonu sınırlar:
///   * `null` — pencere kapanana kadar tekrarlar. `FoodResultScreen` bunu
///     kullanır; analiz bitince widget zaten sonuç görünümüyle değişir.
///   * tamsayı — o kadar tek yönlü geçişten sonra çizgi kaldırılır.
///
/// Onboarding **sonlu bir değer vermek zorundadır**: sonsuz animasyon
/// widget testlerindeki `pumpAndSettle()` çağrılarını zaman aşımına düşürür,
/// ve sayılar zaten ekrandayken durmadan tarayan bir fotoğraf kullanıcıya
/// "hâlâ yükleniyor" der.
class ScanningPhoto extends StatefulWidget {
  final ImageProvider image;
  final int? sweeps;

  const ScanningPhoto({super.key, required this.image, this.sweeps});

  @override
  State<ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<ScanningPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _passes = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.sweeps == null) {
      _controller.repeat(reverse: true);
    } else {
      _controller.addStatusListener(_onPassEnd);
      _controller.forward();
    }
  }

  void _onPassEnd(AnimationStatus status) {
    final isEnd =
        status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed;
    if (!isEnd) return;

    _passes++;
    if (_passes >= widget.sweeps!) {
      if (mounted) setState(() => _finished = true);
      return;
    }
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
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
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: widget.image,
          fit: BoxFit.cover,
          // Varlık yüklenemezse ekran çökmesin; sade bir dolgu yeterli.
          errorBuilder: (_, _, _) => ColoredBox(color: colors.surfaceCard),
        ),
        // Karartma yalnızca tarama sürerken: bittiğinde fotoğraf net kalsın.
        if (!_finished) Container(color: Colors.black.withValues(alpha: 0.18)),
        if (!_finished)
          AnimatedBuilder(
            key: const ValueKey('scan-line'),
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanLinePainter(
                  progress: _controller.value,
                  color: colors.primary,
                ),
              );
            },
          ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ViewfinderCornersPainter(color: colors.primary),
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0;
    final top = inset;
    final bottom = size.height - inset;
    final y = top + (bottom - top) * progress;

    final bandHeight = size.height * 0.18;
    final bandRect = Rect.fromLTWH(
      inset,
      y - bandHeight,
      size.width - inset * 2,
      bandHeight,
    );
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.22)],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const pad = 12.0;
    final len = size.shortestSide * 0.10;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(len * dx, 0), p);
      canvas.drawLine(origin, origin.translate(0, len * dy), p);
    }

    corner(const Offset(pad, pad), 1, 1);
    corner(Offset(size.width - pad, pad), -1, 1);
    corner(Offset(pad, size.height - pad), 1, -1);
    corner(Offset(size.width - pad, size.height - pad), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter old) =>
      old.color != color;
}
