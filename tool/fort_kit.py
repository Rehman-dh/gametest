"""Fortress kit for level design: builds Siege 3-style castles (towers,
curtain walls, gatehouses in one contiguous row, defenders on top).

Usage from a script run at the project root:

    from fort_kit import Row, save
    r = Row(28)                       # left edge of the castle
    r.tower(3.0, 8, 1.0, unit='legionary')
    r.wall(4.0, 3.2, 0.7, m='marble', unit='soldier')
    lp, rp, lintel, gap_mid = r.gate(2.2, 5.5, 3.2, 1.8)
    r.unit('king', gap_mid, 0)
    r.spire()
    save('rome_02', r)                # rewrites blocks/units/props/world
"""
import json, sys

GAP = 0.02

class Row:
    def __init__(self, x):
        self.x = x          # current left edge
        self.blocks = []
        self.units = []
        self.props = []

    def _add(self, w, h, look, hp, m='stone', y=0, **kw):
        cx = round(self.x + w / 2, 3)
        b = {'m': m, 'x': cx, 'y': y, 'w': w, 'h': h}
        if look: b['look'] = look
        if hp is not None: b['hp'] = hp
        b.update(kw)
        self.blocks.append(b)
        self.x = round(self.x + w + GAP, 3)
        return b

    def tower(self, w, h, hp=1.0, unit=None, **kw):
        b = self._add(w, h, 'tower', hp, **kw)
        if unit: self.units.append({'kind': unit, 'x': b['x'], 'y': h})
        return b

    def wall(self, w, h, hp=0.8, unit=None, **kw):
        b = self._add(w, h, 'wall', hp, **kw)
        if unit: self.units.append({'kind': unit, 'x': b['x'], 'y': h})
        return b

    def spire(self, w=2.8, h=9, hp=2):
        return self._add(w, h, 'spire', hp)

    def space(self, w):
        self.x = round(self.x + w, 3)

    def gate(self, pillar_w, pillar_h, gap, lintel_h, pillar_hp=0.4,
             lintel_hp=2.0, left=None, lintel_look='wall', lintel_m='stone'):
        """Two pillars and a lintel; returns (left pillar, right pillar,
        lintel, gap centre). [left] overrides the left pillar's dict."""
        if left:
            lw = left.pop('w')
            lp = self._add(lw, pillar_h, left.pop('look', None),
                           left.pop('hp', None), **left)
        else:
            lw = pillar_w
            lp = self._add(pillar_w, pillar_h, 'tower', pillar_hp)
        gl = self.x
        self.x = round(self.x + gap, 3)
        rp = self._add(pillar_w, pillar_h, 'tower', pillar_hp)
        left_edge = lp['x'] - lw / 2
        right_edge = rp['x'] + pillar_w / 2
        lw_total = round(right_edge - left_edge, 3)
        lin = {'m': lintel_m, 'x': round((left_edge + right_edge) / 2, 3),
               'y': pillar_h, 'w': lw_total, 'h': lintel_h}
        if lintel_look: lin['look'] = lintel_look
        lin['hp'] = lintel_hp
        self.blocks.append(lin)
        return lp, rp, lin, round(gl + gap / 2, 3)

    def unit(self, kind, x, y):
        self.units.append({'kind': kind, 'x': round(x, 3), 'y': round(y, 3)})

    def right(self):
        return max(b['x'] + b['w'] / 2 for b in self.blocks)


def save(level_id, row, keep_props=True, phase_blocks=None, world=None):
    p = f'assets/levels/{level_id}.json'
    d = json.load(open(p))
    d['blocks'] = row.blocks
    d['units'] = row.units
    if row.props or not keep_props:
        d['props'] = row.props
    right = row.right()
    for ph in d.get('phases', []):
        for b in ph.get('blocks', []):
            right = max(right, b['x'] + b['w'] / 2)
    d['worldWidth'] = world or round(right + 3)
    json.dump(d, open(p, 'w'), indent=2)
    print(level_id, 'blocks', len(row.blocks), 'units', len(row.units),
          'world', d['worldWidth'])



if __name__ == '__main__':
    print(__doc__)
