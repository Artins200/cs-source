#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Оффлайн-симулятор ToxicBots: пиши фразы как в чат CS:S и смотри, что ответят боты.
  python tools/sim.py                  — интерактивно
  python tools/sim.py "ты еблан" ...   — разово
  python tools/sim.py --events         — примеры событий (слив раунда, худший игрок и т.д.)
  python tools/sim.py --nice "..."     — ответ бота в нормальном (не токсичном) настроении
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tblib import load_dir, Gen  # noqa: E402
import engine  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def make_ctx(data, k=3, d=11):
    ctx = {'name': 'Игрок', 'bot': 'Bot Vasya', 'kd': '%d-%d' % (k, d), 'k': k, 'd': d,
           'map': 'de_dust2', 'weapon': 'AK-47', 'num': 4, 'target': 'Игрок', 'worst': 'Игрок',
           'wk': 0, 'wd': 1, 'wdmg': 27, 'best': 'Bot Petya', 'score': '3:9', 'round': 12,
           'bk': 7, 'bd': 4, 'bkd': '7-4', 'rk': 3, 'ck': 1, 'cd': 9, 'cmd': 'иду за тобой на Б', 'site': 'Б',
           'tkd': '2-9', 'duel': 'на ножах', 'dirtyw': 'с AWP', 'cmdwhere': 'идти на Б', 'wname': 'калаш', 'have': 'калаш', 'rules': 'бомбу ставить можно'}
    g = Gen(data)
    ctx['perf'] = g.expand('{perf_bad}' if k <= d else '{perf_good}', ctx)
    return ctx


def main():
    data = load_dir(os.path.join(ROOT, 'phrases'))
    args = sys.argv[1:]
    nice = '--nice' in args
    args = [a for a in args if a != '--nice']
    if args and args[0] == '--events':
        for ev in sorted(data.events):
            ctx = make_ctx(data)
            print('[%s]' % ev)
            for _ in range(3):
                print('   ', engine.event_line(data, ev, 'team', ctx))
        return
    if args:
        for a in args:
            ctx = make_ctx(data)
            side = random.choice(['enemy', 'team'])
            rep, why = engine.reply(data, a, side, ctx, nice=nice)
            print('> %s\n  [%s | %s] %s' % (a, side, why, rep))
        return
    print('ToxicBots симулятор. Пиши фразу (пусто = выход).')
    while True:
        try:
            a = input('ты: ').strip()
        except EOFError:
            break
        if not a:
            break
        side = random.choice(['enemy', 'team'])
        rep, why = engine.reply(data, a, side, make_ctx(data))
        print('бот (%s, %s): %s' % (side, why, rep))


if __name__ == '__main__':
    main()
