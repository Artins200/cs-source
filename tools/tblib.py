# -*- coding: utf-8 -*-
"""
ToxicBots — эталонная реализация движка ответов на Python.
Тот же алгоритм реализован на Squirrel в toxicbots/scripts/vscripts/toxicbots/main.nut.

  * парсинг исходников фраз   phrases/*.txt
  * сборка data.nut для игры   tools/build.py
  * подсчёт вариантов          tools/build.py
  * оффлайн-симулятор          tools/sim.py
"""
import os
import random
import re

# ---------------------------------------------------------------- нормализация
HOMO = {'a': 'а', 'e': 'е', 'o': 'о', 'p': 'р', 'c': 'с', 'x': 'х', 'y': 'у', 'k': 'к',
        'm': 'м', 't': 'т', 'h': 'н', 'b': 'в', '3': 'з', '0': 'о', '6': 'б', '4': 'ч', '@': 'а'}
LAYOUT = dict(zip("qwertyuiop[]asdfghjkl;'zxcvbnm,.`", "йцукенгшщзхъфывапролджэячсмитьбюё"))
TRANSLIT_MULTI = [("shch", "щ"), ("sch", "щ"), ("sh", "ш"), ("ch", "ч"), ("zh", "ж"), ("kh", "х"),
                  ("ts", "ц"), ("ya", "я"), ("yu", "ю"), ("yo", "е"), ("ye", "е"), ("ja", "я"),
                  ("ju", "ю"), ("jo", "е"), ("y", "ы")]
TRANSLIT_ONE = dict(zip("abvgdezijklmnoprstufhcwqx", "абвгдезийклмнопрстуфхцвкх"))


def lower_cp(c):
    if 0x41 <= c <= 0x5A or 0x410 <= c <= 0x42F:
        return c + 32
    if c in (0x401, 0x451):
        return 0x435
    return c


def is_cyr(c):
    return 0x430 <= c <= 0x44F


def is_tok_char(c):
    return 0x61 <= c <= 0x7A or 0x30 <= c <= 0x39 or is_cyr(c) or c == 42 or c == 64


def tokenize(text, raws=None):
    """-> токены (списки кодпоинтов). В raws (если передан) кладутся исходные слова в нижнем регистре."""
    cps = []
    for ch in text:
        c = ord(ch)
        cps.append(0x451 if c == 0x401 else (c if c == 0x451 else lower_cp(c)))
    toks, cur = [], []
    for c in cps + [32]:
        if is_tok_char(c) or c == 0x451:
            cur.append(c)
        elif cur:
            toks.append(cur)
            cur = []
    if raws is not None:
        raws.extend(''.join(chr(c) for c in t) for t in toks)
    toks = [[0x435 if c == 0x451 else c for c in t] for t in toks]
    out = []
    for t in toks:
        if any(is_cyr(c) for c in t):
            t = [ord(HOMO[chr(c)]) if chr(c) in HOMO else c for c in t]
        d = []
        for c in t:
            if not d or d[-1] != c:
                d.append(c)
        out.append(d)
    return out


def text_variants(text):
    low = text.lower()
    vs = [text]
    if not any(is_cyr(lower_cp(ord(c))) for c in text) and any('a' <= c <= 'z' for c in low):
        vs.append(''.join(LAYOUT.get(c, c) for c in low))
        out, i = '', 0
        while i < len(low):
            for a, b in TRANSLIT_MULTI:
                if low.startswith(a, i):
                    out += b
                    i += len(a)
                    break
            else:
                out += TRANSLIT_ONE.get(low[i], low[i])
                i += 1
        vs.append(out)
        vs.append(''.join('у' if c == 'y' else HOMO.get(c, c) for c in low))
    return vs


def tstr(t):
    return ''.join(chr(c) for c in t)


# ---------------------------------------------------------------- нечёткое сравнение
def eq(a, b):
    return a == b or a == 42 or b == 42


def lev(a, b, cap=3):
    la, lb = len(a), len(b)
    if abs(la - lb) > cap:
        return cap + 1
    prev = list(range(lb + 1))
    for i in range(1, la + 1):
        cur = [i] + [0] * lb
        best = i
        for j in range(1, lb + 1):
            v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (0 if eq(a[i - 1], b[j - 1]) else 1))
            cur[j] = v
            best = min(best, v)
        if best > cap:
            return cap + 1
        prev = cur
    return prev[lb]


def starts(tok, key, off=0):
    if len(tok) - off < len(key):
        return False
    for i, c in enumerate(key):
        if not eq(tok[off + i], c):
            return False
    return True


EXACT, PREFIX, CONTAINS, SUFFIX = 0, 1, 2, 3


def part_score(tok, mode, key):
    n, lt = len(key), len(tok)
    if mode == EXACT:
        if lt == n and starts(tok, key):
            return 1.0
        if n >= 5 and abs(lt - n) <= 1 and lev(tok, key, 1) <= 1:
            return 0.8
        if n >= 8 and abs(lt - n) <= 2 and lev(tok, key, 2) <= 2:
            return 0.7
        return 0.0
    if mode == PREFIX:
        if starts(tok, key):
            return 1.0
        if n >= 4:
            for L in (n, n - 1, n + 1):
                if 1 <= L <= lt and lev(tok[:L], key, 1) <= 1:
                    return 0.8
        return 0.0
    if mode == CONTAINS:
        for s in range(0, lt - n + 1):
            if starts(tok, key, s):
                return 1.0
        return 0.0
    if mode == SUFFIX:
        return 1.0 if lt >= n and starts(tok, key, lt - n) else 0.0
    return 0.0


def parse_key(raw, default_w):
    """'иди_нах*:30' | '*хуй*' | 'такой>' -> [weight, capnext, [[mode, cps], ...]]"""
    w = default_w
    m = re.match(r'^(.*?):(\d+)$', raw)
    if m:
        raw, w = m.group(1), int(m.group(2))
    capnext = 0
    if raw.endswith('>'):
        capnext, raw = 1, raw[:-1]
    parts = []
    for p in raw.split('_'):
        if not p:
            continue
        if p.startswith('*') and p.endswith('*') and len(p) > 2:
            mode, p = CONTAINS, p[1:-1]
        elif p.endswith('*'):
            mode, p = PREFIX, p[:-1]
        elif p.startswith('*'):
            mode, p = SUFFIX, p[1:]
        else:
            mode = EXACT
        tk = tokenize(p)
        if len(tk) != 1:
            raise ValueError("bad key part %r in %r" % (p, raw))
        parts.append([mode, tk[0]])
    return [w, capnext, parts]


def key_match(toks, key):
    """-> (score 0..1, индекс захваченного токена)"""
    w, capnext, parts = key
    k = len(parts)
    best, cap, start = 0.0, -1, -1
    for i in range(0, len(toks) - k + 1):
        s = 1.0
        for j in range(k):
            ps = part_score(toks[i + j], parts[j][0], parts[j][1])
            if ps <= 0:
                s = 0
                break
            s = min(s, ps)
        if s > best:
            best = s
            start = i
            cap = i + k if (capnext and i + k < len(toks)) else i + k - 1
    return best, cap, start


# ---------------------------------------------------------------- парсер phrases/*.txt
class Data:
    def __init__(self):
        self.slots = {}      # name -> [templates]
        self.intents = []    # dicts
        self.events = {}     # name -> {all:[], team:[], enemy:[]}
        self.classics = []   # [input, reply]


def load_dir(path):
    d = Data()
    for fn in sorted(os.listdir(path)):
        if fn.endswith('.txt'):
            load_file(d, os.path.join(path, fn))
    return d


def load_file(d, fn):
    cur, kind, section = None, None, 'all'
    with open(fn, encoding='utf-8-sig') as f:
        for ln, line in enumerate(f, 1):
            line = line.rstrip('\n').rstrip('\r')
            s = line.strip()
            if not s or s.startswith('#'):
                continue
            try:
                if s.startswith('@'):
                    head = s[1:].split()
                    kind = head[0]
                    section = 'all'
                    if kind == 'slot':
                        cur = d.slots.setdefault(head[1], [])
                    elif kind == 'intent':
                        cur = {'name': head[1], 'w': 10, 'keys': [], 'all': [], 'team': [], 'enemy': [],
                               'nice': [], 'nice_team': [], 'nice_enemy': [],
                               'short': 0, 'prio': 0, 'rawkeys': []}
                        d.intents.append(cur)
                    elif kind == 'nice':
                        # @nice имя — дружелюбные ответы для уже объявленного интента
                        cur = [x for x in d.intents if x['name'] == head[1]]
                        if not cur:
                            raise ValueError('@nice: нет интента ' + head[1])
                        cur = cur[0]
                        section = 'nice'
                    elif kind == 'event':
                        cur = d.events.setdefault(head[1], {'all': [], 'team': [], 'enemy': []})
                    elif kind == 'classic':
                        cur = d.classics
                    else:
                        raise ValueError('unknown section ' + kind)
                    continue
                if kind == 'slot':
                    cur.append(s)
                elif kind == 'classic':
                    a, b = s.split('=>', 1)
                    cur.append([a.strip(), b.strip()])
                elif kind in ('intent', 'event', 'nice'):
                    if s.startswith('>'):
                        section = s[1:].strip()
                        if kind == 'nice':
                            section = 'nice' if section == 'all' else 'nice_' + section
                        assert section in ('all', 'team', 'enemy', 'nice', 'nice_team', 'nice_enemy'), section
                        continue
                    if kind == 'intent' and re.match(r'^(keys|weight|short|prio):', s):
                        k, v = s.split(':', 1)
                        if k == 'keys':
                            cur['rawkeys'] += v.split()
                        else:
                            cur['w' if k == 'weight' else k] = int(v)
                        continue
                    cur[section].append(s)
            except Exception as e:
                raise SystemExit('%s:%d: %s  (%s)' % (fn, ln, e, s))
    for it in d.intents:
        it['keys'] = [parse_key(r, it['w']) for r in it['rawkeys']]


# ---------------------------------------------------------------- шаблоны
def split_top(s, sep='|'):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch in '{[':
            depth += 1
        elif ch in '}]':
            depth -= 1
        if ch == sep and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return out


def find_close(s, i):
    depth = 0
    for j in range(i, len(s)):
        if s[j] in '{[':
            depth += 1
        elif s[j] in '}]':
            depth -= 1
            if depth == 0:
                return j
    return len(s) - 1


def cap_first(s):
    for i, ch in enumerate(s):
        if ch.isalpha():
            return s[:i] + ch.upper() + s[i + 1:]
    return s


def low_first(s):
    for i, ch in enumerate(s):
        if ch.isalpha():
            if i + 1 < len(s) and s[i + 1].isupper():
                return s
            return s[:i] + ch.lower() + s[i + 1:]
    return s


class Gen:
    def __init__(self, data, rnd=random):
        self.d = data
        self.r = rnd

    def expand(self, s, ctx, depth=0):
        if depth > 10:
            return ''
        out, i = '', 0
        while i < len(s):
            ch = s[i]
            if ch == '{' or ch == '[':
                j = find_close(s, i)
                inner = s[i + 1:j]
                if ch == '[':
                    if self.r.random() < 0.5:
                        out += self.expand(inner, ctx, depth + 1)
                else:
                    alts = split_top(inner)
                    if len(alts) > 1:
                        out += self.expand(self.r.choice(alts), ctx, depth + 1)
                    else:
                        out += self.ref(inner, ctx, depth)
                i = j + 1
            else:
                out += ch
                i += 1
        return out

    def ref(self, name, ctx, depth):
        capital = name[:1].isupper()
        key = name[:1].lower() + name[1:]
        if key in ctx:
            v = str(ctx[key])
        elif key in self.d.slots and self.d.slots[key]:
            v = self.expand(self.r.choice(self.d.slots[key]), ctx, depth + 1)
        else:
            v = ''
        return cap_first(v) if capital else v


def tidy(s):
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'\s+([,.!?)])', r'\1', s)
    s = re.sub(r'([,.!?])\1+', r'\1', s) if '...' not in s else s
    s = s.replace(',.', '.').replace('.,', ',')
    return cap_first(s)


# ---------------------------------------------------------------- подсчёт вариантов
class Counter:
    def __init__(self, data):
        self.d = data
        self.memo = {}

    def slot(self, name, stack=()):
        if name in self.memo:
            return self.memo[name]
        if name in stack:
            return 1
        n = sum(self.tmpl(t, stack + (name,)) for t in self.d.slots.get(name, [])) or 1
        self.memo[name] = n
        return n

    def tmpl(self, s, stack=()):
        total, i = 1, 0
        while i < len(s):
            ch = s[i]
            if ch in '{[':
                j = find_close(s, i)
                inner = s[i + 1:j]
                if ch == '[':
                    total *= 1 + self.tmpl(inner, stack)
                else:
                    alts = split_top(inner)
                    if len(alts) > 1:
                        total *= sum(self.tmpl(a, stack) for a in alts)
                    else:
                        k = inner[:1].lower() + inner[1:]
                        total *= self.slot(k, stack) if k in self.d.slots else 1
                i = j + 1
            else:
                i += 1
        return total

    def lst(self, items):
        return sum(self.tmpl(t) for t in items)
