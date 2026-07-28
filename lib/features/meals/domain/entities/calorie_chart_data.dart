import 'package:equatable/equatable.dart';

import '../../../../core/constants/macro_reference_constants.dart';

enum CaloriePeriod { day, week, month, year }

class CalorieBucket extends Equatable {
  final double kcal;
  final double proteinKcal;
  final double carbKcal;
  final double fatKcal;

  const CalorieBucket({
    this.kcal = 0,
    this.proteinKcal = 0,
    this.carbKcal = 0,
    this.fatKcal = 0,
  });

  double get macroKcal => proteinKcal + carbKcal + fatKcal;

  @override
  List<Object?> get props => [kcal, proteinKcal, carbKcal, fatKcal];
}

class CalorieChartData extends Equatable {
  final CaloriePeriod period;

  /// Dönem başlangıcı (dahil) ve bitişi (hariç).
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<CalorieBucket> buckets;
  final double totalKcal;
  final double proteinKcal;
  final double carbKcal;
  final double fatKcal;

  /// İçinde en az bir öğün olan gün sayısı — günlük ortalamanın paydası.
  /// Boş günleri paydaya katmak "az yedin" yanılgısı üretir; referans
  /// uygulamalar da yalnızca veri olan günleri ortalar.
  final int daysWithData;

  const CalorieChartData({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.buckets,
    this.totalKcal = 0,
    this.proteinKcal = 0,
    this.carbKcal = 0,
    this.fatKcal = 0,
    this.daysWithData = 0,
  });

  bool get isEmpty => totalKcal == 0;

  double get avgKcalPerDay =>
      daysWithData == 0 ? 0 : totalKcal / daysWithData;

  double get _macroTotal => proteinKcal + carbKcal + fatKcal;

  // Paylar toplam makro-kcal'e göredir (calories alanına değil) — üçü
  // her zaman 100'e tamamlanır; spec §8 ile tutarlı.
  double get proteinPct =>
      _macroTotal == 0 ? 0 : proteinKcal / _macroTotal * 100;
  double get carbPct => _macroTotal == 0 ? 0 : carbKcal / _macroTotal * 100;
  double get fatPct => _macroTotal == 0 ? 0 : fatKcal / _macroTotal * 100;

  MacroLevel get proteinLevel => MacroReferenceConstants.levelFor(
        proteinPct,
        min: MacroReferenceConstants.proteinMinPct,
        max: MacroReferenceConstants.proteinMaxPct,
      );
  MacroLevel get carbLevel => MacroReferenceConstants.levelFor(
        carbPct,
        min: MacroReferenceConstants.carbMinPct,
        max: MacroReferenceConstants.carbMaxPct,
      );
  MacroLevel get fatLevel => MacroReferenceConstants.levelFor(
        fatPct,
        min: MacroReferenceConstants.fatMinPct,
        max: MacroReferenceConstants.fatMaxPct,
      );

  @override
  List<Object?> get props => [
        period,
        rangeStart,
        rangeEnd,
        buckets,
        totalKcal,
        proteinKcal,
        carbKcal,
        fatKcal,
        daysWithData,
      ];
}
