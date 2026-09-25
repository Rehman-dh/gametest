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
    return ColoredBox(
      color: const Color(0xF20E0B09),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _scoutReport()),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: _armoryPanel()),
            ],
          ),
        ),
      ),
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
    final lines = [
      objective,
      [
        if (count(UnitKind.king) > 0) 'king',
        if (count(UnitKind.soldier) > 0) '${count(UnitKind.soldier)} soldiers',
        if (count(UnitKind.archer) > 0) '${count(UnitKind.archer)} archers',
        if (count(UnitKind.engineer) > 0)
          '${count(UnitKind.engineer)} engineers',
      ].join(', '),
      if (weakPoints > 0)
        _showWeakPoints
            ? '$weakPoints weak point${weakPoints > 1 ? 's' : ''} marked'
            : 'Rumours of a weak point',
      if (level.wind != 0)
        'Wind ${level.wind > 0 ? 'at your back' : 'in your face'}',
      if (level.hasCounterFire) 'They will shoot back',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.game.showMap,
              icon: const Icon(Icons.arrow_back, color: UiStyle.parchment),
            ),
            Expanded(
              child: Text(
                level.name.toUpperCase(),
                style: UiStyle.heading.copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
        for (final line in lines)
          Text('• $line', style: UiStyle.body.copyWith(fontSize: 13)),
      ],
    );
  }

  Widget _armoryPanel() {
    final weapons = armory.weaponsFor(level);
    final onSale = armory.ammoFor(level, weapon);
    final available = armory.availableCrew();
    return Container(
      padding: const EdgeInsets.all(12),
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
                    children: [
                      for (final w in WeaponType.values)
                        ChoiceChip(
                          label: Text(w.spec.label),
                          selected: w == weapon,
                          onSelected: weapons.contains(w)
                              ? (_) => setState(() {
                                  weapon = w;
                                  _suggestAmmo();
                                })
                              : null,
                        ),
                    ],
                  ),
                  if (level.weaponLocked)
                    Text(
                      'This siege calls for the ${level.weapon.spec.label}.',
                      style: UiStyle.body.copyWith(
                        fontSize: 12,
                        color: UiStyle.bronze,
                      ),
                    ),
                  const SizedBox(height: 10),
                  _label('AMMUNITION'),
                  for (final type in onSale) _ammoRow(type),
                  const SizedBox(height: 10),
                  _label('CREW  (${crew.length}/${armory.crewSlots()})'),
                  if (available.isEmpty)
                    Text(
                      'No one has joined you yet.',
                      style: UiStyle.body.copyWith(
                        fontSize: 12,
                        color: UiStyle.bronze,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final id in available)
                        FilterChip(
                          label: Text(
                            '${crewSpecs[id]!.name} · ${crewSpecs[id]!.role}'
                            ' Lv ${widget.game.campaign!.progress.value.crewLevel(id)}',
                          ),
                          selected: crew.contains(id),
                          onSelected: (_) => _toggleCrew(id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: UiStyle.bronze),
          Row(
            children: [
              const Icon(Icons.paid_outlined, color: UiStyle.bronze, size: 18),
              const SizedBox(width: 6),
              Text('${budget - spent} of $budget left', style: UiStyle.body),
              const Spacer(),
              FilledButton.icon(
                onPressed: rounds == 0 ? null : _begin,
                style: FilledButton.styleFrom(
                  backgroundColor: UiStyle.blood,
                  foregroundColor: UiStyle.parchment,
                ),
                icon: const Icon(Icons.flag),
                label: const Text('BEGIN SIEGE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: UiStyle.body.copyWith(
        fontSize: 11,
        letterSpacing: 2,
        color: UiStyle.bronze,
      ),
    ),
  );

  Widget _ammoRow(AmmoType type) {
    final count = counts[type] ?? 0;
    return Row(
      children: [
        AmmoIcon(type: type, theme: widget.game.theme, size: 30),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${type.spec.label}  ·  ${armory.priceOf(type)}',
            style: UiStyle.body.copyWith(fontSize: 14),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: count > 0 ? () => _change(type, -1) : null,
          icon: const Icon(
            Icons.remove_circle_outline,
            color: UiStyle.parchment,
          ),
        ),
        SizedBox(
          width: 22,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: UiStyle.body,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: spent + armory.priceOf(type) <= budget
              ? () => _change(type, 1)
              : null,
          icon: const Icon(Icons.add_circle_outline, color: UiStyle.parchment),
        ),
      ],
    );
  }
}
