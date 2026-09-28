/// Supported intermittent fasting protocols, named by the fast:eat window split.
enum FastingProtocol {
  p16_8,
  p18_6,
  p20_4,
  omad;

  /// Length of the fasting window in minutes.
  int get fastMinutes => switch (this) {
        FastingProtocol.p16_8 => 16 * 60,
        FastingProtocol.p18_6 => 18 * 60,
        FastingProtocol.p20_4 => 20 * 60,
        FastingProtocol.omad => 23 * 60,
      };

  /// Human-readable label shown in the UI and stored with the user's plan.
  String get label => switch (this) {
        FastingProtocol.p16_8 => '16:8',
        FastingProtocol.p18_6 => '18:6',
        FastingProtocol.p20_4 => '20:4',
        FastingProtocol.omad => 'OMAD',
      };

  /// Parses a stored [label] back into a protocol; unknown or null falls
  /// back to 16:8.
  static FastingProtocol fromLabel(String? label) => switch (label) {
        '18:6' => FastingProtocol.p18_6,
        '20:4' => FastingProtocol.p20_4,
        'OMAD' => FastingProtocol.omad,
        _ => FastingProtocol.p16_8,
      };
}
