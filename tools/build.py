#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Собирает phrases/*.txt -> toxicbots/scripts/vscripts/toxicbots/data.nut
и считает, сколько разных ответов умеет генерировать мод.
  python tools/build.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tblib import load_dir, Counter, tokenize, tstr  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'toxicbots', 'scripts', 'vscripts', 'toxicbots', 'data.nut')


def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def arr(items, ind='    '):
    if not items:
        return '[]'
    return '[\n' + ''.join('%s%s,\n' % (ind, q(x)) for x in items) + ind[:-4] + ']'


def ints(lst):
    return '[' + ','.join(str(x) for x in lst) + ']'


SECS = ('all', 'team', 'enemy', 'nice', 'nice_team', 'nice_enemy')


def main():
    d = load_dir(os.path.join(ROOT, 'phrases'))
    cnt = Counter(d)
    out = ['// АВТОГЕНЕРАЦИЯ: tools/build.py из phrases/*.txt. Редактируй phrases/, потом запусти build.py.',
           '// (Можно править и прямо тут, если нет Python — синтаксис строк тот же.)',
           '::TB_DATA <- {', 'slots = {']
    for name, items in d.slots.items():
        out.append('  %s = %s,' % (name, arr(items, '      ')))
    out.append('},')
    out.append('intents = [')
    for it in d.intents:
        keys = ','.join('[%d,%d,[%s]]' % (k[0], k[1], ','.join('[%d,%s]' % (m, ints(c)) for m, c in k[2]))
                        for k in it['keys'])
        out.append('  { name = %s, short = %d, prio = %d, keys = [%s],' % (q(it['name']), it['short'], it['prio'], keys))
        for sec in ('all', 'team', 'enemy'):
            out.append('    %s = %s,' % (sec, arr(it[sec], '        ')))
        for sec in ('nice', 'nice_team', 'nice_enemy'):
            if it[sec]:
                out.append('    %s = %s,' % (sec, arr(it[sec], '        ')))
        out.append('  },')
    out.append('],')
    out.append('events = {')
    for name, ev in d.events.items():
        out.append('  %s = {' % name)
        for sec in ('all', 'team', 'enemy'):
            out.append('    %s = %s,' % (sec, arr(ev[sec], '        ')))
        out.append('  },')
    out.append('},')
    out.append('classics = [')
    for a, b in d.classics:
        cps = [ord(c) for c in ' '.join(tstr(t) for t in tokenize(a))]
        out.append('  [%s, %s],' % (ints(cps), q(b)))
    out.append(']')
    out.append('}')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out) + '\n')

    # ---- статистика
    pre = cnt.lst(d.slots.get('pre', []))
    post = cnt.lst(d.slots.get('post', []))
    deco = (1 + pre) * (1 + post)
    total_raw = total = 0
    lines = 0
    print('%-18s %8s %14s' % ('интент/событие', 'шаблонов', 'вариантов'))
    for it in d.intents:
        n = sum(cnt.lst(it[s]) for s in SECS)
        t = sum(len(it[s]) for s in SECS)
        lines += t
        total_raw += n
        total += n * deco
        print('%-18s %8d %14s' % (it['name'], t, format(n, ',')))
    for name, ev in d.events.items():
        n = sum(cnt.lst(ev[s]) for s in ('all', 'team', 'enemy'))
        t = sum(len(ev[s]) for s in ('all', 'team', 'enemy'))
        lines += t
        total_raw += n
        print('%-18s %8d %14s' % ('@' + name, t, format(n, ',')))
    lines += len(d.classics) + sum(len(v) for v in d.slots.values())
    print('-' * 42)
    print('классика (готовые пары):        %d' % len(d.classics))
    print('строк в phrases/:                %d' % lines)
    print('интентов: %d, событий: %d, слотов: %d' % (len(d.intents), len(d.events), len(d.slots)))
    print('уникальных ответов без мат-приставок: %s' % format(total_raw, ','))
    print('с приставками/добивками ("Блять, ...", "... лол"): %s' % format(total, ','))
    print('-> %s (%d KB)' % (os.path.relpath(OUT, ROOT), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
