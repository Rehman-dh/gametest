/// The ages the campaign passes through, each with its own castles, foes
/// and look. A level belongs to the era its id starts with ("rome_03").
enum Era {
  egypt('Egypt', 'I'),
  rome('Rome', 'II'),
  persia('Persia', 'III'),
  medieval('Medieval', 'IV'),
  china('China', 'V'),
  mythic('Mythic', 'VI');

  const Era(this.label, this.numeral);

  final String label;
  final String numeral;

  /// "ERA II · ROME".
  String get title => 'ERA $numeral · ${label.toUpperCase()}';

  /// The era a level id belongs to; generated castles count as Egypt.
  static Era ofLevel(String id) {
    final prefix = id.split('_').first;
    return Era.values.firstWhere(
      (e) => e.name == prefix,
      orElse: () => Era.egypt,
    );
  }
}
