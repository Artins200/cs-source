// =====================================================================
//  ToxicBots — ядро: нормализация текста, нечёткий поиск, генератор фраз.
//  Эталон того же алгоритма на Python: tools/tblib.py + tools/engine.py
// =====================================================================
::TBC <- {}

TBC.Decode <- function(s) {
	local out = [], n = s.len(), i = 0
	while (i < n) {
		local b = s[i] & 0xFF
		if (b < 0x80) { out.push(b); i += 1 }
		else if ((b & 0xE0) == 0xC0 && i + 1 < n) { out.push(((b & 0x1F) << 6) | (s[i+1] & 0x3F)); i += 2 }
		else if ((b & 0xF0) == 0xE0 && i + 2 < n) { out.push(((b & 0x0F) << 12) | ((s[i+1] & 0x3F) << 6) | (s[i+2] & 0x3F)); i += 3 }
		else if ((b & 0xF8) == 0xF0 && i + 3 < n) { out.push(0x3F); i += 4 }
		else { i += 1 }
	}
	return out
}
TBC.EncCp <- function(c) {
	if (c < 0x80) return c.tochar()
	if (c < 0x800) return (0xC0 | (c >> 6)).tochar() + (0x80 | (c & 0x3F)).tochar()
	return (0xE0 | (c >> 12)).tochar() + (0x80 | ((c >> 6) & 0x3F)).tochar() + (0x80 | (c & 0x3F)).tochar()
}
TBC.Encode <- function(cps) {
	local s = ""
	foreach (c in cps) s += TBC.EncCp(c)
	return s
}
TBC.LowerCp <- function(c) {
	if ((c >= 0x41 && c <= 0x5A) || (c >= 0x410 && c <= 0x42F)) return c + 32
	if (c == 0x401 || c == 0x451) return 0x435
	return c
}
TBC.IsCyr <- function(c) { return c >= 0x430 && c <= 0x44F }
TBC.IsTok <- function(c) {
	return (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39) || (c >= 0x430 && c <= 0x44F) || c == 42 || c == 64
}

// ------------------------------------------------------------ таблицы
TBC.MapPairs <- function(from, to) {
	local a = TBC.Decode(from), b = TBC.Decode(to), t = {}
	for (local i = 0; i < a.len(); i++) t[a[i]] <- b[i]
	return t
}
TBC.HOMO <- TBC.MapPairs("aeopcxykmthb3064@", "аеорсхукмтнвзобча")
TBC.LAYOUT <- TBC.MapPairs("qwertyuiop[]asdfghjkl;'zxcvbnm,.`", "йцукенгшщзхъфывапролджэячсмитьбюё")
TBC.TR1 <- TBC.MapPairs("abvgdezijklmnoprstufhcwqx", "абвгдезийклмнопрстуфхцвкх")
TBC.TRM <- [["shch","щ"],["sch","щ"],["sh","ш"],["ch","ч"],["zh","ж"],["kh","х"],["ts","ц"],
	["ya","я"],["yu","ю"],["yo","е"],["ye","е"],["ja","я"],["ju","ю"],["jo","е"],["y","ы"]]
foreach (p in TBC.TRM) { p[0] = TBC.Decode(p[0]); p[1] = TBC.Decode(p[1])[0] }

// ------------------------------------------------------------ токены
// -> { toks = [[cp..]..], raws = ["слово"..] }
TBC.Tokenize <- function(cps) {
	local toks = [], cur = []
	cps = clone cps
	cps.push(32)
	foreach (c0 in cps) {
		local c = c0
		if (c == 0x401) c = 0x451
		else if (c != 0x451) c = TBC.LowerCp(c)
		if (TBC.IsTok(c) || c == 0x451) cur.push(c)
		else if (cur.len() > 0) { toks.push(cur); cur = [] }
	}
	local out = [], raws = []
	foreach (t in toks) {
		raws.push(TBC.Encode(t))
		local cyr = false
		for (local i = 0; i < t.len(); i++) {
			if (t[i] == 0x451) t[i] = 0x435
			if (TBC.IsCyr(t[i])) cyr = true
		}
		local d = []
		foreach (c in t) {
			local x = c
			if (cyr && (x in TBC.HOMO)) x = TBC.HOMO[x]
			if (d.len() == 0 || d[d.len() - 1] != x) d.push(x)
		}
		out.push(d)
	}
	return { toks = out, raws = raws }
}

// оригинал + (если всё латиницей) раскладка, транслит, "похожие буквы"
TBC.Variants <- function(text) {
	local cps = TBC.Decode(text)
	local vs = [cps], low = [], hasCyr = false, hasLat = false
	foreach (c in cps) {
		local l = TBC.LowerCp(c)
		low.push(l)
		if (TBC.IsCyr(l)) hasCyr = true
		if (l >= 0x61 && l <= 0x7A) hasLat = true
	}
	if (hasCyr || !hasLat) return vs
	local lay = [], hom = [], tr = []
	foreach (c in low) {
		lay.push((c in TBC.LAYOUT) ? TBC.LAYOUT[c] : c)
		hom.push(c == 121 ? 0x443 : ((c in TBC.HOMO) ? TBC.HOMO[c] : c))
	}
	local i = 0, n = low.len()
	while (i < n) {
		local hit = false
		foreach (p in TBC.TRM) {
			local pat = p[0], m = pat.len()
			if (i + m > n) continue
			local ok = true
			for (local j = 0; j < m; j++) if (low[i + j] != pat[j]) { ok = false; break }
			if (ok) { tr.push(p[1]); i += m; hit = true; break }
		}
		if (!hit) { tr.push((low[i] in TBC.TR1) ? TBC.TR1[low[i]] : low[i]); i++ }
	}
	vs.push(lay); vs.push(tr); vs.push(hom)
	return vs
}

// ------------------------------------------------------------ нечёткое сравнение
TBC.Eq <- function(a, b) { return a == b || a == 42 || b == 42 }

TBC.Lev <- function(a, b, cap, la = -1) {
	if (la < 0) la = a.len()
	local lb = b.len()
	local df = la - lb
	if (df < 0) df = -df
	if (df > cap) return cap + 1
	local prev = array(lb + 1, 0), cur = array(lb + 1, 0), tmp
	for (local j = 0; j <= lb; j++) prev[j] = j
	for (local i = 1; i <= la; i++) {
		cur[0] = i
		local best = i, ai = a[i - 1]
		for (local j = 1; j <= lb; j++) {
			local v = prev[j] + 1
			local w = cur[j - 1] + 1
			if (w < v) v = w
			local bj = b[j - 1]
			w = prev[j - 1] + ((ai == bj || ai == 42 || bj == 42) ? 0 : 1)
			if (w < v) v = w
			cur[j] = v
			if (v < best) best = v
		}
		if (best > cap) return cap + 1
		tmp = prev; prev = cur; cur = tmp
	}
	return prev[lb]
}

TBC.Starts <- function(tok, key, off) {
	local n = key.len()
	if (tok.len() - off < n) return false
	for (local i = 0; i < n; i++) if (!TBC.Eq(tok[off + i], key[i])) return false
	return true
}

// режимы: 0 точное, 1 начинается с, 2 содержит, 3 заканчивается на
TBC.PartScore <- function(tok, mode, key) {
	local n = key.len(), lt = tok.len()
	if (mode == 0) {
		if (lt == n && TBC.Starts(tok, key, 0)) return 1.0
		local df = lt - n
		if (df < 0) df = -df
		if (n >= 5 && df <= 1 && TBC.Lev(tok, key, 1) <= 1) return 0.8
		if (n >= 8 && df <= 2 && TBC.Lev(tok, key, 2) <= 2) return 0.7
		return 0.0
	}
	if (mode == 1) {
		if (TBC.Starts(tok, key, 0)) return 1.0
		if (n >= 4) {
			if (n <= lt && TBC.Lev(tok, key, 1, n) <= 1) return 0.8
			if (n - 1 <= lt && TBC.Lev(tok, key, 1, n - 1) <= 1) return 0.8
			if (n + 1 <= lt && TBC.Lev(tok, key, 1, n + 1) <= 1) return 0.8
		}
		return 0.0
	}
	if (mode == 2) {
		for (local s = 0; s <= lt - n; s++) if (TBC.Starts(tok, key, s)) return 1.0
		return 0.0
	}
	if (mode == 3) return (lt >= n && TBC.Starts(tok, key, lt - n)) ? 1.0 : 0.0
	return 0.0
}

// key = [weight, capnext, [[mode, [cp..]], ...]] -> [score, capIndex]
TBC.KeyMatch <- function(toks, key, f = null) {
	local parts = key[2], k = parts.len(), best = 0.0, cap = -1, start = -1
	local m0 = parts[0][0], n0 = parts[0][1].len()
	for (local i = 0; i <= toks.len() - k; i++) {
		if (f != null) {   // быстрый отсев слова (см. TBC.KF)
			local t = toks[i], lt = t.len()
			if (lt == 0) continue
			if (m0 == 0 && (lt > n0 + 1 || lt < n0 - 1)) continue
			if (m0 == 1 && lt < n0 - 1) continue
			local c0 = t[0], c1 = (lt > 1) ? t[1] : -1
			if (c0 != f[0] && c0 != f[1] && c1 != f[0] && c1 != f[1]) continue
		}
		local s = 1.0
		for (local j = 0; j < k; j++) {
			local ps = TBC.PartScore(toks[i + j], parts[j][0], parts[j][1])
			if (ps <= 0) { s = 0.0; break }
			if (ps < s) s = ps
		}
		if (s > best) {
			best = s
			start = i
			cap = (key[1] && i + k < toks.len()) ? i + k : i + k - 1
		}
	}
	return [best, cap, start]
}

// ------------------------------------------------------------ анализ сообщения
TBC.MIN_SCORE <- 6.0
TBC.CLASSIC_SIM <- 0.80
TBC.MAT <- ["хуй","хуе","хуи","хуя","пизд","еба","ебл","еби","ебу","бля","сук","нах"]
foreach (i, m in TBC.MAT) TBC.MAT[i] = TBC.Decode(m)
TBC.EXPL <- [TBC.Decode("объясн"), TBC.Decode("поясн")]

// Быстрый отсев ключей (результат тот же, что без него): совпадение с <=1 ошибкой
// невозможно, если ни одна из двух первых букв ключа не стоит в начале какого-то слова.
// KF[i][k] = null (проверять всегда) или [буква0, буква1]
TBC.KF <- []
foreach (it in TB_DATA.intents) {
	local row = []
	foreach (key in it.keys) {
		local p = key[2][0], m = p[0], kc = p[1], n = kc.len(), f = null
		if ((m == 0 && n < 8) || m == 1) {
			if (n >= 2 && kc[0] != 42 && kc[1] != 42) f = [kc[0], kc[1]]
			else if (n == 1 && kc[0] != 42) f = [kc[0], kc[0]]
		}
		row.push(f)
	}
	TBC.KF.push(row)
}

TBC.ScoreIntents <- function(toks) {
	local best = null, bestS = 0.0, bestCap = -1, n = toks.len()
	local heads = {}, wild = false
	foreach (t in toks) {
		if (t.len() > 0) { heads[t[0]] <- 1; if (t[0] == 42) wild = true }
		if (t.len() > 1) { heads[t[1]] <- 1; if (t[1] == 42) wild = true }
	}
	foreach (ii, it in TB_DATA.intents) {
		if (it.short && n > 2) continue
		local s = 0.0, bk = 0.0, cap = -1, per = {}, kf = TBC.KF[ii]
		foreach (ki, key in it.keys) {
			local f = kf[ki]
			if (f != null && !wild && !(f[0] in heads) && !(f[1] in heads)) continue
			local r = TBC.KeyMatch(toks, key, wild ? null : f)
			if (r[0] > 0) {
				local v = key[0] * r[0]
				if (!(r[2] in per) || per[r[2]] < v) per[r[2]] <- v
				if (v > bk) { bk = v; cap = r[1] }
			}
		}
		foreach (v in per) s += v
		s += it.prio
		if (s > bestS) { best = it; bestS = s; bestCap = cap }
	}
	return [best, bestS, bestCap]
}

TBC.Analyze <- function(text) {
	local res = null
	foreach (v in TBC.Variants(text)) {
		local tk = TBC.Tokenize(v)
		local r = TBC.ScoreIntents(tk.toks)
		if (res == null || r[1] > res.score) res = { intent = r[0], score = r[1], cap = r[2], toks = tk.toks, raws = tk.raws }
	}
	if (res.score < TBC.MIN_SCORE) res.intent = null
	res.word <- (res.cap >= 0) ? res.raws[res.cap] : ""
	res.explain <- false
	res.mat <- false
	foreach (t in res.toks) {
		foreach (e in TBC.EXPL) if (TBC.Starts(t, e, 0)) res.explain = true
		foreach (m in TBC.MAT) if (TBC.PartScore(t, 2, m) > 0) res.mat = true
	}
	return res
}

TBC.BestClassic <- function(toks) {
	local q = []
	foreach (i, t in toks) { if (i > 0) q.push(32); q.extend(t) }
	if (q.len() == 0) return null
	local best = null, bs = 0.0
	foreach (c in TB_DATA.classics) {
		local cp = c[0], L = cp.len() > q.len() ? cp.len() : q.len()
		local mn = cp.len() < q.len() ? cp.len() : q.len()
		if (mn < 0.7 * L) continue
		local cap = (L * (1.0 - TBC.CLASSIC_SIM)).tointeger() + 1
		local d = TBC.Lev(q, cp, cap)
		if (d > cap) continue
		local sim = 1.0 - (1.0 * d) / L
		if (sim >= TBC.CLASSIC_SIM && sim > bs) { best = c[1]; bs = sim }
	}
	return best == null ? null : [best, bs]
}

// ------------------------------------------------------------ генератор
TBC.Rnd <- function() { return RandomFloat(0.0, 1.0) }
TBC.Pick <- function(a) { return a[RandomInt(0, a.len() - 1)] }

TBC.FindClose <- function(s, i) {
	local depth = 0
	for (local j = i; j < s.len(); j++) {
		local c = s[j]
		if (c == '{' || c == '[') depth++
		else if (c == '}' || c == ']') { depth--; if (depth == 0) return j }
	}
	return s.len() - 1
}

TBC.SplitTop <- function(s) {
	local out = [], depth = 0, st = 0
	for (local j = 0; j < s.len(); j++) {
		local c = s[j]
		if (c == '{' || c == '[') depth++
		else if (c == '}' || c == ']') depth--
		else if (c == '|' && depth == 0) { out.push(s.slice(st, j)); st = j + 1 }
	}
	out.push(s.slice(st))
	return out
}

// буква в позиции i: 0 — не буква, 1 — строчная, 2 — заглавная; len — байт
TBC.LetterAt <- function(s, i) {
	local b = s[i] & 0xFF
	if (b >= 0x61 && b <= 0x7A) return [1, 1]
	if (b >= 0x41 && b <= 0x5A) return [2, 1]
	if ((b == 0xD0 || b == 0xD1) && i + 1 < s.len()) {
		local b2 = s[i + 1] & 0xFF
		if (b == 0xD0 && (b2 == 0x81 || (b2 >= 0x90 && b2 <= 0xAF))) return [2, 2]
		if ((b == 0xD0 && b2 >= 0xB0) || (b == 0xD1 && (b2 <= 0x8F || b2 == 0x91))) return [1, 2]
	}
	return [0, (b >= 0xC0) ? ((b >= 0xE0) ? 3 : 2) : 1]
}

TBC.CapFirst <- function(s) {
	local i = 0
	while (i < s.len()) {
		local L = TBC.LetterAt(s, i)
		if (L[0] == 2) return s
		if (L[0] == 1) {
			local b = s[i] & 0xFF, rep
			if (L[1] == 1) rep = (b - 32).tochar()
			else {
				local b2 = s[i + 1] & 0xFF
				if (b == 0xD0) rep = (0xD0).tochar() + (b2 - 0x20).tochar()
				else if (b2 == 0x91) rep = (0xD0).tochar() + (0x81).tochar()
				else rep = (0xD0).tochar() + (b2 + 0x20).tochar()
			}
			return s.slice(0, i) + rep + s.slice(i + L[1])
		}
		i += L[1]
	}
	return s
}

TBC.LowFirst <- function(s) {
	local i = 0
	while (i < s.len()) {
		local L = TBC.LetterAt(s, i)
		if (L[0] == 1) return s
		if (L[0] == 2) {
			local nx = i + L[1]
			if (nx < s.len() && TBC.LetterAt(s, nx)[0] == 2) return s
			local b = s[i] & 0xFF, rep
			if (L[1] == 1) rep = (b + 32).tochar()
			else {
				local b2 = s[i + 1] & 0xFF
				if (b2 == 0x81) rep = (0xD1).tochar() + (0x91).tochar()
				else if (b2 <= 0x9F) rep = (0xD0).tochar() + (b2 + 0x20).tochar()
				else rep = (0xD1).tochar() + (b2 - 0x20).tochar()
			}
			return s.slice(0, i) + rep + s.slice(nx)
		}
		i += L[1]
	}
	return s
}

TBC.Expand <- function(s, ctx, depth = 0) {
	if (depth > 10) return ""
	local out = "", i = 0, st = 0, n = s.len()
	while (i < n) {
		local c = s[i]
		if (c == '{' || c == '[') {
			out += s.slice(st, i)
			local j = TBC.FindClose(s, i)
			local inner = s.slice(i + 1, j)
			if (c == '[') {
				if (TBC.Rnd() < 0.5) out += TBC.Expand(inner, ctx, depth + 1)
			} else {
				local alts = TBC.SplitTop(inner)
				if (alts.len() > 1) out += TBC.Expand(TBC.Pick(alts), ctx, depth + 1)
				else out += TBC.Ref(inner, ctx, depth)
			}
			i = j + 1
			st = i
		} else i++
	}
	if (st < n) out += s.slice(st)
	return out
}

TBC.Ref <- function(name, ctx, depth) {
	if (name.len() == 0) return ""
	local f = name[0], capital = (f >= 'A' && f <= 'Z')
	local key = capital ? ((f + 32).tochar() + name.slice(1)) : name
	local v = ""
	if (key in ctx) v = ctx[key].tostring()
	else if ((key in TB_DATA.slots) && TB_DATA.slots[key].len() > 0) v = TBC.Expand(TBC.Pick(TB_DATA.slots[key]), ctx, depth + 1)
	return capital ? TBC.CapFirst(v) : v
}

TBC.IsWs <- function(c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r' }
TBC.IsP <- function(c) { return c == ',' || c == '.' || c == '!' || c == '?' || c == ')' }

TBC.Tidy <- function(s) {
	local out = "", sp = false
	for (local i = 0; i < s.len(); i++) {
		local c = s[i]
		if (TBC.IsWs(c)) { sp = true; continue }
		if (sp && out.len() > 0 && !TBC.IsP(c)) out += " "
		sp = false
		out += c.tochar()
	}
	if (out.find("...") == null) {
		local r = "", prev = 0
		for (local i = 0; i < out.len(); i++) {
			local c = out[i]
			if ((c == ',' || c == '.' || c == '!' || c == '?') && c == prev) continue
			r += c.tochar()
			prev = c
		}
		out = r
	}
	local r2 = "", i = 0
	while (i < out.len()) {
		if (i + 1 < out.len() && out[i] == ',' && out[i + 1] == '.') { r2 += "."; i += 2; continue }
		if (i + 1 < out.len() && out[i] == '.' && out[i + 1] == ',') { r2 += ","; i += 2; continue }
		r2 += out[i].tochar(); i++
	}
	return TBC.CapFirst(r2)
}

// ------------------------------------------------------------ ответ
TBC.PickPool <- function(sec, side) {
	local sideL = (side != null && (side in sec)) ? sec[side] : []
	local allL = sec.all
	if (sideL.len() > 0 && (allL.len() == 0 || TBC.Rnd() < 0.5)) return sideL
	return allL.len() > 0 ? allL : sideL
}

// первое слово в нижнем регистре без знаков: "Блять," -> "блять"
TBC.FirstWord <- function(s) {
	local w = [], cps = TBC.Decode(s)
	foreach (c in cps) {
		local l = TBC.LowerCp(c)
		if (TBC.IsTok(l)) w.push(l)
		else if (w.len() > 0) break
	}
	return TBC.Encode(w)
}
TBC._pre <- null
TBC.PreFirst <- function() {
	if (TBC._pre == null) {
		TBC._pre = {}
		foreach (p in TB_DATA.slots.pre) TBC._pre[TBC.FirstWord(p)] <- 1
	}
	return TBC._pre
}

TBC.Decorate <- function(core, a, ctx) {
	local slots = TB_DATA.slots
	if (TBC.Rnd() < (a.mat ? TB_CFG.pre_chance_mat : TB_CFG.pre_chance) && ("pre" in slots)) {
		local pre = TBC.Expand(TBC.Pick(slots.pre), ctx)
		local nm = ("name" in ctx) ? ctx.name : "\x01"
		if (!(TBC.FirstWord(core) in TBC.PreFirst()) && core.find(nm) != 0) core = pre + ", " + TBC.LowFirst(core)
	}
	if (TBC.Rnd() < TB_CFG.post_chance && ("post" in slots)) {
		local post = TBC.Expand(TBC.Pick(slots.post), ctx)
		local last = core.len() > 0 ? core[core.len() - 1] : 0
		if ((last == '.' || last == '!' || last == '?') && post.len() > 0 && TBC.LetterAt(post, 0)[0] != 0)
			post = TBC.CapFirst(post) + "."
		core = core + " " + post
	}
	return TBC.Tidy(core)
}

// дружелюбный пул интента: nice_<side> / nice
TBC.NicePool <- function(sec, side) {
	local key = "nice_" + side
	local sideL = (key in sec) ? sec[key] : [], allL = ("nice" in sec) ? sec.nice : []
	if (sideL.len() > 0 && (allL.len() == 0 || TBC.Rnd() < 0.5)) return sideL
	return allL.len() > 0 ? allL : sideL
}

// a = TBC.Analyze(text), side = "enemy" | "team", nice = бот в нормальном настроении -> [строка, отладка]
TBC.Reply <- function(a, side, ctx, nice = false) {
	ctx.word <- (a.word != "") ? a.word : "ты"
	if (nice) {
		local pool = (a.intent != null) ? TBC.NicePool(a.intent, side) : []
		if (pool.len() == 0) pool = TB_DATA.events.nice_fallback.all
		return [TBC.Tidy(TBC.Expand(TBC.Pick(pool), ctx)), "nice " + (a.intent != null ? a.intent.name : "-")]
	}
	local cl = TBC.BestClassic(a.toks)
	if (cl != null && TBC.Rnd() < (cl[1] > 0.97 ? TB_CFG.classic_exact_chance : TB_CFG.classic_chance))
		return [TBC.Tidy(TBC.Expand(cl[0], ctx)), "classic"]
	local pool, why
	if (a.intent != null) {
		if (a.explain && TBC.Rnd() < 0.6) { pool = TB_DATA.events.explain.all; why = "explain" }
		else { pool = TBC.PickPool(a.intent, side); why = a.intent.name }
	} else { pool = TB_DATA.events.fallback.all; why = "fallback" }
	local core = TBC.Tidy(TBC.Expand(TBC.Pick(pool), ctx))
	return [TBC.Decorate(core, a, ctx), why]
}

TBC.EventLine <- function(name, side, ctx) {
	if (!(name in TB_DATA.events)) return null
	local pool = TBC.PickPool(TB_DATA.events[name], side)
	if (pool.len() == 0) return null
	local t = TBC.Pick(pool), snd = ""
	if (t.len() > 5 && t.slice(0, 5) == "(snd:") {
		local e = t.find(")")
		if (e != null) { snd = t.slice(5, e); t = t.slice(e + 1) }
	}
	local out = TBC.Tidy(TBC.Expand(t, ctx))
	// у фразы есть готовая озвучка -> маркер \x02имя\x02 в начале (снимает main.nut)
	return (snd != "") ? ("\x02" + snd + "\x02" + out) : out
}

// ------------------------------------------------------------ настроение сообщения
TBC.IDX <- {}
foreach (i, it in TB_DATA.intents) TBC.IDX[it.name] <- i

// очки конкретного интента (0 — не похоже)
TBC.IntentScore <- function(name, toks) {
	if (!(name in TBC.IDX)) return 0.0
	local ii = TBC.IDX[name], it = TB_DATA.intents[ii], per = {}, s = 0.0
	foreach (key in it.keys) {
		local r = TBC.KeyMatch(toks, key)
		if (r[0] > 0) { local v = key[0] * r[0]; if (!(r[2] in per) || per[r[2]] < v) per[r[2]] <- v }
	}
	foreach (v in per) s += v
	return s
}

// хамство в сообщении -> слово, которым обозвали ("еблан"), или null.
// Короткие ключи — только без опечаток, чтобы "бомбу" не стало "бомжом".
TBC.RUDE <- ["insult", "noob", "go_away", "mother"]
TBC.RudeWord <- function(a) {
	foreach (n in TBC.RUDE) {
		if (!(n in TBC.IDX)) continue
		foreach (key in TB_DATA.intents[TBC.IDX[n]].keys) {
			local r = TBC.KeyMatch(a.toks, key)
			if (r[0] >= 0.95 || (r[0] > 0 && key[2][0][1].len() >= 6)) return a.raws[r[2]]
		}
	}
	return null
}

// вежливые/дружеские слова (начало слова)
TBC.POLITE <- []
foreach (w in ["ребят", "парн", "пацан", "братв", "чувак", "мужик", "друз", "народ", "пожалуйст", "плиз", "плз",
	"пж", "please", "pls", "спасиб", "спс", "давайте", "можешь", "можете", "прошу", "бро", "братан", "братиш", "команда"])
	TBC.POLITE.push(TBC.Decode(w))
TBC.IsPolite <- function(toks) {
	foreach (t in toks) foreach (w in TBC.POLITE) if (TBC.Starts(t, w, 0)) return true
	return false
}

// "на б", "го а", "раш би" -> "Б" / "А" / ""
TBC.SITE_A <- {}
TBC.SITE_B <- {}
foreach (w in ["а", "a", "эй", "ей", "ay"]) TBC.SITE_A[TBC.Encode(TBC.Decode(w))] <- 1
foreach (w in ["б", "b", "би", "бэ", "бе", "bi"]) TBC.SITE_B[TBC.Encode(TBC.Decode(w))] <- 1
TBC.SITE_PRE <- {}
foreach (w in ["на", "го", "раш", "в", "к", "все", "идем", "идём", "пошли", "погнали", "стак", "держим", "сайт", "плент", "плэнт"])
	TBC.SITE_PRE[w] <- 1
TBC.Site <- function(a) {
	local r = a.raws
	for (local i = 0; i < r.len(); i++) {
		local w = TBC.Encode(TBC.Decode(r[i]).map(function(c) { return TBC.LowerCp(c) }))
		local prev = (i > 0) ? TBC.Encode(TBC.Decode(r[i - 1]).map(function(c) { return TBC.LowerCp(c) })) : ""
		local okPre = (prev in TBC.SITE_PRE) || r.len() <= 2
		if (okPre && (w in TBC.SITE_A)) return "А"
		if (okPre && (w in TBC.SITE_B)) return "Б"
	}
	return ""
}
