import 'package:flutter/material.dart';

import '../../core/ammo.dart';
import '../../core/weapons.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../../meta/catalog.dart';
import '../../meta/loadout.dart';
import '../ui_style.dart';
import '../widgets/ammo_icon.dart';
import '../widgets/blueprint.dart';

/// Pre-battle screen: study the scout's blueprint, pick a weapon, buy
/// ammunition within the siege budget and choose crew.
class SiegePrep extends StatefulWidget {
  const SiegePrep({super.key, required this.game});

  final SiegeGame game;

  @override
  State<SiegePrep> createState() => _SiegePrepState();
}

class _SiegePrepState extends State<SiegePrep> {
  late final LevelData level =
      widget.game.campaign!.levels[widget.game.prepIndex];
  late final Armory armory = widget.game.campaign!.armory;
  late final int budget = armory.budgetFor(level);
  late WeaponType weapon;
  final Map<AmmoType, int> counts = {};
  final List<CrewId> crew = [];

  int get spent =>
      counts.entries.fold(0, (sum, e) => sum + armory.priceOf(e.key) * e.value);
  int get rounds => counts.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    final weapons = armory.weaponsFor(level);
    weapon = weapons.contains(level.weapon) ? level.weapon : weapons.first;
    _suggestAmmo();
    crew.addAll(armory.availableCrew().take(armory.crewSlots()));
  }

  /// The level's own loadout when it fits this weapon, else plain rounds.
  void _suggestAmmo() {
    counts.clear();
    final onSale = armory.ammoFor(level, weapon);
    for (final a in level.ammo) {
      if (onSale.contains(a) && spent + armory.priceOf(a) <= budget) {
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      final basic = onSale.first;
      counts[basic] = budget ~/ armory.priceOf(basic);
    }
  }

  void _change(AmmoType type, int delta) {
    final next = (counts[type] ?? 0) + delta;
    if (next < 0) return;
    if (delta > 0 && spent + armory.priceOf(type) > budget) return;
    setState(() => counts[type] = next);
  }

  void _toggleCrew(CrewId id) {
    setState(() {
      if (crew.contains(id)) {
        crew.remove(id);
      } else if (crew.length < armory.crewSlots()) {
        crew.add(id);
      }
    });
  }

  void _begin() {
    final ammo = [
      for (final type in AmmoType.values)
        for (var i = 0; i < (counts[type] ?? 0); i++) type,
    ];
    if (ammo.isEmpty) return;
    widget.game.startLevel(
      widget.game.prepIndex,
      loadout: Loadout(weapon: weapon, ammo: ammo, crew: List.of(crew)),
    );
  }

  bool get _showWeakPoints =>
      widget.game.campaign!.progress.value.building(BuildingId.warRoom) >= 2 ||
      crew.contains(CrewId.liWei);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FB4E8), Color(0xFFA9DEF6)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: PopIn(
                        delay: const Duration(milliseconds: 80),
                        from: const Offset(-0.15, 0),
                        child: _scoutReport(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: PopIn(
                        delay: const Duration(milliseconds: 160),
                        from: const Offset(0.15, 0),
                        child: _armoryPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        PopIn(
          from: const Offset(-0.5, 0),
          child: CartoonButton(
            icon: Icons.arrow_back_rounded,
            tone: ButtonTone.plain,
            size: 0.85,
            onPressed: widget.game.showMap,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: PopIn(
            from: const Offset(0, -0.4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RibbonTitle(level.name.toUpperCase()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoutReport() {
    int count(UnitKind k) => level.units.where((u) => u.kind == k).length;
    final weakPoints =
        level.blocks.where((b) => b.weak).length +
        level.props.where((p) => p.kind == PropKind.powderBarrel).length;
    final objective = switch (level.objective) {
      Objective.killAll => 'Defeat every defender',
      Objective.killKing => 'Slay the king',
      Objective.destroyEngines => 'Wreck the enemy siege engines',
    };
    final lines = <(IconData, String)>[
      (Icons.flag_rounded, objective),
      (
        Icons.groups_rounded,
        [
          if (count(UnitKind.king) > 0) 'king',
          if (count(UnitKind.soldier) > 0)
            '${count(UnitKind.soldier)} soldiers',
          if (count(UnitKind.archer) > 0) '${count(UnitKind.archer)} archers',
          if (count(UnitKind.engineer) > 0)
            '${count(UnitKind.engineer)} engineers',
        ].join(', '),
      ),
      if (weakPoints > 0)
        (
          Icons.gps_fixed_rounded,
          _showWeakPoints
              ? '$weakPoints weak point${weakPoints > 1 ? 's' : ''} marked'
              : 'Rumours of a weak point',
        ),
      if (level.wind != 0)
        (
          Icons.air_rounded,
          'Wind ${level.wind > 0 ? 'at your back' : 'in your face'}',
        ),
      if (level.hasCounterFire) (Icons.warning_rounded, 'They will shoot back'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: UiStyle.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('SCOUT REPORT'),
          Expanded(
            child: CustomPaint(
              painter: BlueprintPainter(
                level: level,
                showWeakPoints: _showWeakPoints,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          for (final (icon, line) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: UiStyle.blood),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line,
                      style: UiStyle.body.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _armoryPanel() {
    final weapons = armory.weaponsFor(level);
    final onSale = armory.ammoFor(level, weapon);
    final available = armory.availableCrew();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: UiStyle.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('SIEGE ENGINE'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in WeaponType.values)
                        _ChoiceTile(
                          label: w.spec.label,
                          selected: w == weapon,
                          onTap: weapons.contains(w)
                              ? () => setState(() {
                                  weapon = w;
                                  _suggestAmmo();
                                })
                              : null,
                        ),
                    ],
                  ),
                  if (level.weaponLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'This siege calls for the ${level.weapon.spec.label}.',
                        style: _note,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _label('AMMUNITION'),
                  for (final type in onSale) _ammoRow(type),
                  const SizedBox(height: 8),
                  _label('CREW  (${crew.length}/${armory.crewSlots()})'),
                  if (available.isEmpty)
                    Text('No one has joined you yet.', style: _note),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in available)
                        _ChoiceTile(
                          label:
                              '${crewSpecs[id]!.name} · ${crewSpecs[id]!.role}'
                              ' Lv ${widget.game.campaign!.progress.value.crewLevel(id)}',
                          selected: crew.contains(id),
                          icon: crew.contains(id)
                              ? Icons.check_circle_rounded
                              : Icons.person_add_alt_1_rounded,
                          onTap: () => _toggleCrew(id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                    decoration: UiStyle.insetDecoration,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Coin(size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '${budget - spent} of $budget left',
                          style: UiStyle.body.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CartoonButton(
                label: 'Begin siege',
                icon: Icons.flag_rounded,
                tone: ButtonTone.green,
                size: 0.95,
                onPressed: rounds == 0 ? null : _begin,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle get _note => UiStyle.body.copyWith(
    fontSize: 12,
    color: UiStyle.ink.withValues(alpha: 0.65),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: UiStyle.body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: UiStyle.blood,
      ),
    ),
  );

  Widget _ammoRow(AmmoType type) {
    final count = counts[type] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: UiStyle.insetDecoration,
      child: Row(
        children: [
          AmmoIcon(type: type, theme: widget.game.theme, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type.spec.label,
              style: UiStyle.body.copyWith(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const _Coin(size: 16),
          const SizedBox(width: 3),
          Text(
            '${armory.priceOf(type)}',
            style: UiStyle.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          CartoonButton(
            icon: Icons.remove_rounded,
            tone: ButtonTone.red,
            size: 0.75,
            onPressed: count > 0 ? () => _change(type, -1) : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: UiStyle.body.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          CartoonButton(
            icon: Icons.add_rounded,
            tone: ButtonTone.green,
            size: 0.75,
            onPressed: spent + armory.priceOf(type) <= budget
                ? () => _change(type, 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// A chunky, outlined tile that can be picked: gold when selected, faded
/// when unavailable.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0xFFFFF0A8), UiStyle.gold]
                    : const [Colors.white, UiStyle.panelDeep],
              ),
              border: Border.all(color: UiStyle.ink, width: selected ? 3 : 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x44000000), offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? UiStyle.leaf : UiStyle.ink,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: UiStyle.body.copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A little gold coin for prices and the budget.
class _Coin extends StatelessWidget {
  const _Coin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: UiStyle.gold,
        shape: BoxShape.circle,
        border: Border.all(color: UiStyle.ink, width: size > 18 ? 2.5 : 2),
      ),
      // An inner rim, like a stamped coin.
      child: Container(
        width: size * 0.45,
        height: size * 0.45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: UiStyle.bronze, width: size * 0.09),
        ),
      ),
    );
  }
}
