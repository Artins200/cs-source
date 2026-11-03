# -*- coding: utf-8 -*-
"""Логика выбора ответа (эталон для main.nut)."""
import random
import re
from tblib import (tokenize, text_variants, key_match, tstr, lev, Gen, tidy, cap_first, low_first)

MIN_SCORE = 6.0
CLASSIC_SIM = 0.80
MAT_STEMS = ["хуй", "хуе", "хуи", "хуя", "пизд", "еба", "ебл", "еби", "ебу", "бля", "сук", "нах"]


def score_intents(data, toks):
    best = (None, 0.0, -1)
    n = len(toks)
    for it in data.intents:
        if it['short'] and n > 2:
            continue
        bk, cap, per = 0.0, -1, {}
        for key in it['keys']:
            m, c, st = key_match(toks, key)
            if m > 0:
                v = key[0] * m
                per[st] = max(per.get(st, 0), v)
                if v > bk:
                    bk, cap = v, c
        s = sum(per.values()) + it['prio']
        if s > best[1]:
            best = (it, s, cap)
    return best


def analyze(data, text):
    res = (None, 0.0, -1, [], [])
    for v in text_variants(text):
        raws = []
        toks = tokenize(v, raws)
        it, s, cap = score_intents(data, toks)
        if s > res[1] or not res[3]:
            res = (it, s, cap, toks, raws)
    it, s, cap, toks, raws = res
    if s < MIN_SCORE:
        it = None
    flat = [tstr(t) for t in toks]
    explain = any(t.startswith("объясн") or t.startswith("поясн") for t in flat)
    mat = any(any(st in t for st in MAT_STEMS) for t in flat)
    return {'intent': it, 'score': s, 'word': raws[cap] if cap >= 0 else '', 'toks': toks,
            'explain': explain, 'mat': mat, 'q': '?' in text}


def classic_norm(text):
    return [c for c in ' '.join(tstr(t) for t in tokenize(text))]


def best_classic(data, toks, cache={}):
    key = id(data)
    if key not in cache:
        cache[key] = [([ord(c) for c in classic_norm(a)], b) for a, b in data.classics]
    q = [ord(c) for c in ' '.join(tstr(t) for t in toks)]
    best, bs = None, 0.0
    if not q:
        return None, 0.0
    for cp, rep in cache[key]:
        L = max(len(cp), len(q))
        if min(len(cp), len(q)) < 0.7 * L:
            continue
        cap = int(L * (1 - CLASSIC_SIM)) + 1
        d = lev(q, cp, cap)
        if d > cap:
            continue
        sim = 1.0 - d / L
        if sim >= CLASSIC_SIM and sim > bs:
            best, bs = rep, sim
    return best, bs


def first_word(s):
    t = tokenize(s)
    return tstr(t[0]) if t else ''


def pick_pool(sec, side, r):
    side_l = sec.get(side, []) if side else []
    all_l = sec.get('all', [])
    if side_l and (not all_l or r.random() < 0.5):
        return side_l
    return all_l or side_l


def decorate(core, a, data, gen, ctx, r):
    if r.random() < (0.5 if a['mat'] else 0.25) and data.slots.get('pre'):
        pre = gen.expand(r.choice(data.slots['pre']), ctx)
        prefirst = {first_word(x) for x in data.slots['pre']}
        if first_word(core) not in prefirst and not core.startswith(str(ctx.get('name', '\x00'))):
            core = pre + ', ' + low_first(core)
    if r.random() < 0.2 and data.slots.get('post'):
        post = gen.expand(r.choice(data.slots['post']), ctx)
        if core[-1:] in '.!?' and post[:1].isalpha():
            post = cap_first(post) + '.'
        core = core + ' ' + post
    return tidy(core)


def nice_pool(sec, side, r):
    return pick_pool({'all': sec.get('nice', []), side: sec.get('nice_' + side, [])}, side, r)


def reply(data, text, side, ctx, r=random, nice=False):
    """side: 'enemy' | 'team'. nice=True — бот в нормальном настроении. Возвращает (ответ, отладка)."""
    gen = Gen(data, r)
    a = analyze(data, text)
    ctx = dict(ctx)
    ctx['word'] = a['word'] or 'ты'
    if nice:
        it = a['intent']
        pool = nice_pool(it, side, r) if it is not None else []
        why = 'nice ' + (it['name'] if it is not None else '-')
        if not pool:
            ev = 'nice_fallback_q' if (a['q'] and it is None) else 'nice_fallback'
            pool, why = data.events[ev]['all'], why + ' (' + ev + ')'
        return tidy(gen.expand(r.choice(pool), ctx)), '%s %.1f' % (why, a['score'])
    rep, sim = best_classic(data, a['toks'])
    if rep and r.random() < (0.8 if sim > 0.97 else 0.55):
        return tidy(gen.expand(rep, ctx)), 'classic %.2f' % sim
    it = a['intent']
    if it is not None:
        if a['explain'] and r.random() < 0.6:
            pool, why = data.events['explain']['all'], 'explain+' + it['name']
        else:
            pool, why = pick_pool(it, side, r), it['name']
    elif a['q']:
        pool, why = data.events['fallback_q']['all'], 'fallback_q'
    else:
        pool, why = data.events['fallback']['all'], 'fallback'
    core = tidy(gen.expand(r.choice(pool), ctx))
    return decorate(core, a, data, gen, ctx, r), '%s %.1f word=%s' % (why, a['score'], a['word'])


def event_line(data, name, side, ctx, r=random):
    gen = Gen(data, r)
    ev = data.events[name]
    t = r.choice(pick_pool(ev, side, r))
    snd = ''
    m = re.match(r'^\(snd:(\w+)\)\s*', t)
    if m:
        snd, t = m.group(1), t[m.end():]
    return tidy(gen.expand(t, ctx)) + ('  [звук: %s.wav]' % snd if snd else '')
