// =====================================================================
//  ToxicBots — оружие: «дропни калаш», дуэли «на ножах / на диглах / на AWP».
//  Оружие ботам выдаём и отбираем через сущности (Kill / SpawnEntityFromTable),
//  а бот-ИИ ограничиваем квотами bot_allow_* (если сервер даёт выполнять команды).
// =====================================================================

// id = как оружие называется в событии player_death (weapon_<id> — класс)
// cat: knife pistol rifle sniper shotgun smg mg grenade
TB.WPN <- [
	{ id = "knife",     cat = "knife",   nom = "нож",        ins = "с ножом",          pl = "на ножах",         keys = ["нож", "knife", "финк", "перо", "ножи"] },
	{ id = "deagle",    cat = "pistol",  nom = "дигл",       ins = "с диглом",         pl = "на диглах",        keys = ["дигл", "деагл", "дигал", "дегл", "deagle", "дезерт", "deag"] },
	{ id = "awp",       cat = "sniper",  nom = "AWP",        ins = "с AWP",            pl = "на AWP",           keys = ["авп", "awp", "avp", "слон", "авик", "эвп", "авпх"] },
	{ id = "scout",     cat = "sniper",  nom = "скаут",      ins = "со скаутом",       pl = "на скаутах",       keys = ["скаут", "scout", "муха", "мухе", "мухах", "мухи"] },
	{ id = "ak47",      cat = "rifle",   nom = "калаш",      ins = "с калашом",        pl = "на калашах",       keys = ["калаш", "калах", "акаш", "ак47", "ak47", "акм", "акашк", "калик"], exact = ["ак", "ak", "ака", "аке", "ках"] },
	{ id = "m4a1",      cat = "rifle",   nom = "M4",         ins = "с эмкой",          pl = "на эмках",         keys = ["эмк", "эмочк", "m4", "м4", "колт", "кольт", "мка"] },
	{ id = "usp",       cat = "pistol",  nom = "USP",        ins = "с юспом",          pl = "на юспах",         keys = ["юсп", "usp", "юспи"] },
	{ id = "glock",     cat = "pistol",  nom = "глок",       ins = "с глоком",         pl = "на глоках",        keys = ["глок", "glock"] },
	{ id = "p228",      cat = "pistol",  nom = "P228",       ins = "с P228",           pl = "на P228",          keys = ["p28", "п28", "компакт"] },
	{ id = "elite",     cat = "pistol",  nom = "беретты",    ins = "с береттами",      pl = "на береттах",      keys = ["берет", "дуал", "элит", "elite", "dual"] },
	{ id = "fiveseven", cat = "pistol",  nom = "Five-Seven", ins = "с Five-Seven",     pl = "на Five-Seven",    keys = ["файв", "фив", "five"] },
	{ id = "m3",        cat = "shotgun", nom = "M3",         ins = "с помпой",         pl = "на помпах",        keys = ["помп", "дробаш", "дробовик", "шотган"], exact = ["m3", "м3"] },
	{ id = "xm1014",    cat = "shotgun", nom = "XM1014",     ins = "с автодробом",     pl = "на автодробах",    keys = ["xm1014", "автодроб", "иксэм"] },
	{ id = "mp5navy",   cat = "smg",     nom = "MP5",        ins = "с MP5",            pl = "на MP5",           keys = ["мп5", "mp5", "мпх", "эмпэ"] },
	{ id = "p90",       cat = "smg",     nom = "P90",        ins = "с P90",            pl = "на P90",           keys = ["п90", "p90", "пешк", "пэха"] },
	{ id = "tmp",       cat = "smg",     nom = "TMP",        ins = "с TMP",            pl = "на TMP",           keys = ["tmp", "тмп"] },
	{ id = "mac10",     cat = "smg",     nom = "MAC-10",     ins = "с маком",          pl = "на маках",         keys = ["mac10", "мак10", "узи"], exact = ["mac", "мак"] },
	{ id = "ump45",     cat = "smg",     nom = "UMP",        ins = "с UMP",            pl = "на UMP",           keys = ["умп", "ump"] },
	{ id = "famas",     cat = "rifle",   nom = "фамас",      ins = "с фамасом",        pl = "на фамасах",       keys = ["фамас", "famas", "фамс"] },
	{ id = "galil",     cat = "rifle",   nom = "галиль",     ins = "с галилем",        pl = "на галилях",       keys = ["галил", "galil"] },
	{ id = "sg552",     cat = "rifle",   nom = "SG552",      ins = "с кригом",         pl = "на кригах",        keys = ["sg52", "криг", "крег"] },
	{ id = "aug",       cat = "rifle",   nom = "AUG",        ins = "с аугом",          pl = "на аугах",         keys = ["ауг", "aug"] },
	{ id = "sg550",     cat = "sniper",  nom = "SG550",      ins = "с автоснайперкой", pl = "на автоснайперках", keys = ["sg50"] },
	{ id = "g3sg1",     cat = "sniper",  nom = "G3SG1",      ins = "с автоснайперкой", pl = "на автоснайперках", keys = ["g3sg1", "автоснайп", "автосн", "джитри"], exact = ["g3"] },
	{ id = "m249",      cat = "mg",      nom = "пулемёт",    ins = "с пулемётом",      pl = "на пулемётах",     keys = ["пулем", "пулём", "m249", "м249", "машинган"] },
	{ id = "hegrenade", cat = "grenade", nom = "граната",    ins = "с гранатой",       pl = "на гранатах",      keys = ["гранат", "хаешк", "хешк", "хэшк", "граник", "хаеш"] }
]
// целые классы оружия для дуэлей: «на пистолетах», «на снайперках»...
TB.WCAT <- [
	{ cat = "pistol",  give = "deagle", pl = "на пистолетах", keys = ["пистол", "пестик", "пистал", "пистик", "пушках"] },
	{ cat = "sniper",  give = "awp",    pl = "на снайперках", keys = ["снайп", "снайперк", "снипер"] },
	{ cat = "rifle",   give = "ak47",   pl = "на автоматах",  keys = ["автомат", "винтовк", "райфл"] },
	{ cat = "shotgun", give = "m3",     pl = "на дробовиках", keys = ["дробовиках", "дробовики", "шотганах"] },
	{ cat = "smg",     give = "mp5navy", pl = "на пп",        keys = ["пэпэ", "смг", "smg", "пулеметиках"] }
]
TB.WBYID <- {}
foreach (w in TB.WPN) TB.WBYID[w.id] <- w
TB.CAT_CV <- { pistol = "bot_allow_pistols", shotgun = "bot_allow_shotguns", smg = "bot_allow_sub_machine_guns",
	rifle = "bot_allow_rifles", mg = "bot_allow_machine_guns", grenade = "bot_allow_grenades", sniper = "bot_allow_snipers" }

// слова сообщения в нижнем регистре (строки)
TB.Words <- function(a) {
	local out = []
	foreach (t in a.toks) out.push(TBC.Encode(t))
	return out
}
TB.Trim <- function(s) {
	local a = 0, b = s.len()
	while (a < b && s[a] <= 32 && s[a] >= 0) a++
	while (b > a && s[b - 1] <= 32 && s[b - 1] >= 0) b--
	return s.slice(a, b)
}
TB.Pre <- function(w, p) { return w.len() >= p.len() && w.slice(0, p.len()) == p }
// оружие в одном слове: { w = запись TB.WPN } / { c = запись TB.WCAT } / null
TB.WeaponOf <- function(w) {
	foreach (c in TB.WCAT) foreach (k in c.keys) if (TB.Pre(w, k)) return { c = c }
	foreach (e in TB.WPN) {
		if ("exact" in e) foreach (k in e.exact) if (w == k) return { w = e }
		foreach (k in e.keys) if (TB.Pre(w, k)) return { w = e }
	}
	return null
}
// всё оружие в тексте: [{ w|c, neg }] — neg = «не на AWP», «без гранат»
TB.ParseWeapons <- function(a) {
	local words = TB.Words(a), out = []
	foreach (i, w in words) {
		local p = TB.WeaponOf(w)
		if (p == null) continue
		local p1 = (i > 0) ? words[i - 1] : "", p2 = (i > 1) ? words[i - 2] : ""
		p.na <- p1 == "на" || p1 == "пвп" || p1 == "дуэль"
		p.neg <- p1 == "не" || p1 == "без" || p1 == "кроме" || ((p1 == "на" || p1 == "с" || p1 == "со") && (p2 == "не" || p2 == "без"))
		out.push(p)
	}
	return out
}
// первое «не отрицаемое» оружие
TB.ParseWeapon <- function(a) {
	foreach (p in TB.ParseWeapons(a)) if (!p.neg) return p
	return null
}

// ------------------------------------------------------------ инвентарь
TB.Weapons <- function(p) {
	local arr = []
	try {
		for (local i = 0; i < 48; i++) {
			local w = NetProps.GetPropEntityArray(p, "m_hMyWeapons", i)
			if (w != null && w.IsValid()) arr.push(w)
		}
	} catch (e) { if (TB_CFG.debug) printl("[ToxicBots] оружие: " + e) }
	return arr
}
TB.WId <- function(w) {
	local c = w.GetClassname()
	return (c.len() > 7 && c.slice(0, 7) == "weapon_") ? c.slice(7) : c
}
TB.KillEnt <- function(e) {
	try { e.Kill() } catch (x) { try { e.Destroy() } catch (y) {} }
}
TB.SpawnWeapon <- function(id, pos) {
	try { return SpawnEntityFromTable("weapon_" + id, { origin = pos }) } catch (e) { printl("[ToxicBots] не выдать " + id + ": " + e) }
	return null
}
TB.Dist <- function(a, b) {
	try { return (a.GetOrigin() - b.GetOrigin()).Length() } catch (e) {}
	return 0.0
}

// ------------------------------------------------------------ серверные команды (кик, bot_allow_*)
TB.SrvCmd <- function(cmd) {
	if (!TB_CFG.server_commands) return false
	try {
		local v = Convars.GetStr("sv_allow_point_servercommand")
		if (v == "disallow") return false
	} catch (e) {}
	try { SendToServerConsole(cmd); return true } catch (e) { if (TB_CFG.debug) printl("[ToxicBots] команда не прошла: " + e) }
	return false
}

// ------------------------------------------------------------ «дропни калаш»
TB.dropPending <- null   // { bot, id, until }
TB.DropName <- function(w) { local id = TB.WId(w); return (id in TB.WBYID) ? TB.WBYID[id].nom : id }
// что бот может отдать: нужное оружие или лучшее (основное -> пистолет)
TB.DropPick <- function(bot, want) {
	local prim = null, sec = null, found = null
	foreach (w in TB.Weapons(bot)) {
		local id = TB.WId(w)
		if (!(id in TB.WBYID)) continue
		local e = TB.WBYID[id]
		if (want != null && (("w" in want) ? want.w.id == id : want.c.cat == e.cat)) found = w
		if (e.cat == "pistol") sec = w
		else if (e.cat != "knife" && e.cat != "grenade") prim = w
	}
	return { found = found, best = (prim != null) ? prim : sec }
}
TB.DoDrop <- function(bot, w, human) {
	local id = TB.WId(w)
	local pos = null
	try {
		local d = bot.GetOrigin() - human.GetOrigin()
		local L = d.Length()
		if (L > 1.0) d = d * (1.0 / L)
		// кладём к ногам игрока (чуть в сторону бота), чтобы бот не подобрал обратно
		pos = human.GetOrigin() + d * 28.0 + Vector(0, 0, 12)
	} catch (e) { return false }
	TB.KillEnt(w)
	return TB.SpawnWeapon(id, pos) != null
}
TB.OnDrop <- function(human, a, rude, polite) {
	local want = TB.ParseWeapon(a)
	if (want != null && ("w" in want) && want.w.cat == "knife") want = null
	local ht = human.GetTeam(), mates = TB.Bots(ht)
	local bot = TB.FindMentioned(a.toks, TB.Bots())
	if (bot != null && bot.GetTeam() != ht) mates = []
	if (mates.len() == 0) {
		local foe = (bot != null) ? bot : TB.PickBot(a, human, false)
		if (foe != null) { TB.BotSay(foe, TB.Ev("drop_enemy", foe, TB.Ctx(human, foe), null, true), false); TB.Talked(foe) }
		return
	}
	if (bot == null) {
		// у кого есть то, что просят; иначе ближайший живой
		local best = null, bd = 1000000000.0
		foreach (b in mates) {
			if (!TB.Alive(b)) continue
			local pk = TB.DropPick(b, want)
			local d = TB.Dist(b, human) - ((want != null && pk.found != null) ? 5000 : 0) - ((pk.best != null) ? 2000 : 0)
			if (d < bd) { bd = d; best = b }
		}
		bot = (best != null) ? best : TBC.Pick(mates)
	}
	local ctx = TB.Ctx(human, bot)
	ctx.wname <- (want == null) ? "ствол" : (("w" in want) ? want.w.nom : want.c.pl.slice(3))
	ctx.word <- (a.rudeWord != "") ? a.rudeWord : "так"
	TB.Talked(bot)
	if (!TB.Alive(bot)) { TB.BotSay(bot, TBC.EventLine("drop_dead", null, ctx), true); return }
	local pk = TB.DropPick(bot, want)
	local w = (want != null) ? pk.found : pk.best
	ctx.have <- (pk.best != null) ? TB.DropName(pk.best) : "нож"
	if (pk.best == null) { TB.BotSay(bot, TBC.EventLine("drop_knife", null, ctx), true); return }
	if (w == null) { TB.BotSay(bot, TB.Ev("drop_none", bot, ctx, null, TB.IsToxic(bot, rude, polite)), true); return }
	ctx.have = TB.DropName(w)
	if (rude && TBC.Rnd() < 0.9) { TB.BotSay(bot, TBC.EventLine("drop_refuse_rude", null, ctx), true); return }
	if (TBC.Rnd() > TB.ObeyChance(rude, polite)) { TB.BotSay(bot, TBC.EventLine("drop_refuse", null, ctx), true); return }
	local toxic = TB.IsToxic(bot, rude, polite, a.mat)
	if (TB.Dist(bot, human) > TB_CFG.drop_distance) {
		TB.dropPending = { bot = bot.entindex(), id = TB.WId(w), until = Time() + 45.0, toxic = toxic }
		TB.BotSay(bot, TBC.EventLine("drop_far", null, ctx), true)
		return
	}
	if (TB.DoDrop(bot, w, human)) TB.BotSay(bot, TB.Ev("drop_ok", bot, ctx, null, toxic), true)
}
// think: игрок подошёл к боту, который обещал дропнуть
TB.DropTick <- function(now) {
	local p = TB.dropPending
	if (p == null) return
	local bot = PlayerInstanceFromIndex(p.bot), human = TB.Human()
	if (now > p.until || bot == null || !bot.IsValid() || human == null || !TB.Alive(bot) || !TB.Alive(human)) { TB.dropPending = null; return }
	if (TB.Dist(bot, human) > 320.0) return
	TB.dropPending = null
	foreach (w in TB.Weapons(bot)) {
		if (TB.WId(w) != p.id) continue
		if (TB.DoDrop(bot, w, human)) {
			local ctx = TB.Ctx(human, bot)
			ctx.have <- TB.WBYID[p.id].nom
			TB.BotSay(bot, TB.Ev("drop_ok", bot, ctx, null, p.toxic), true)
		}
		return
	}
}

// ------------------------------------------------------------ дуэли
// TB.duel = { spec, round, active, ids = {id=1}, give, disp, cv }
TB.duel <- null
TB.dirty <- 0          // сколько раз ты нарушил дуэль
TB.dirtyW <- ""        // чем («с AWP»)
TB.dirtyDisp <- ""     // какая была дуэль («на ножах»)
TB.dirtyT <- -100.0    // когда было последнее нарушение (можно оправдаться: «не купил», «случайно»)
TB.dirtyBot <- -1      // кого убили не тем оружием
TB.dirtyRound <- -100  // в каком раунде нарушил (отказы в дуэлях со временем забываются)
TB.offerNextRound <- 0 // раньше этого раунда боты сами дуэль не предлагают
TB.offer <- null       // бот предложил дуэль: { spec, bot, until }
TB.roundStartT <- -100.0
TB.roundNo <- 0
TB.money <- {}         // деньги ботов на начало раунда (дуэль не должна их разорять)
TB.giveNext <- {}

// спецификация дуэли из списка оружия: «ножи и диглы» -> всё перечисленное разрешено
TB.SpecOf <- function(list) {
	local s = { ids = { knife = 1 }, give = null, disp = "на ножах", cats = {}, bomb = true }
	local names = [], nades = null
	foreach (p in list) {
		local pl
		if ("w" in p) {
			if (p.w.cat == "grenade") { nades = p.w.pl; continue }
			s.ids[p.w.id] <- 1
			if (p.w.cat != "knife") { s.cats[p.w.cat] <- 1; if (s.give == null) s.give = p.w.id }
			pl = p.w.pl
		} else {
			foreach (e in TB.WPN) if (e.cat == p.c.cat) s.ids[e.id] <- 1
			s.cats[p.c.cat] <- 1
			if (s.give == null) s.give = p.c.give
			pl = p.c.pl
		}
		local dup = false
		foreach (n in names) if (n == pl) dup = true
		if (!dup) names.push(pl)
	}
	if (nades != null) {
		s.ids.hegrenade <- 1; s.cats.grenade <- 1
		if (names.len() == 0) { s.give = "hegrenade"; names.push(nades) }
		else s.nades <- true
	}
	if (names.len() > 0) {
		local d = names[0]
		for (local i = 1; i < names.len(); i++) {
			local sp = names[i].find(" ")   // «на диглах» -> «диглах» (строки — байты, режем по пробелу)
			d += " и " + ((sp != null) ? names[i].slice(sp + 1) : names[i])
		}
		s.disp = d
	}
	return s
}
TB.DuelSpec <- function(a) {
	local pos = []
	foreach (p in TB.ParseWeapons(a)) if (!p.neg) pos.push(p)
	local s = TB.SpecOf(pos)
	local r = TB.DuelRules(TB.Words(a))
	if (r != null && r.bomb != null) s.bomb = r.bomb
	return s
}
// «сила» оружия: убил хуже договорённого (глок в дуэли на диглах) — это не нарушение
TB.WTIER <- { knife = 0, glock = 1, usp = 1, p228 = 1, elite = 1, fiveseven = 1, hegrenade = 1, deagle = 2,
	tmp = 3, mac10 = 3, mp5navy = 3, ump45 = 3, p90 = 3, m3 = 3, xm1014 = 3, scout = 3,
	galil = 4, famas = 4, ak47 = 4, m4a1 = 4, sg552 = 4, aug = 4, m249 = 4, awp = 5, g3sg1 = 5, sg550 = 5 }
TB.WeakerKill <- function(wid, d) {
	if (!(wid in TB.WTIER) || ("free" in d)) return false
	local top = 0
	foreach (id, v in d.ids) if ((id in TB.WTIER) && TB.WTIER[id] > top) top = TB.WTIER[id]
	return TB.WTIER[wid] < top
}
// «один на один» с конкретным ботом: оружие любое (если не названо), остальным лезть нельзя
TB.OneVOneSpec <- function(bot, a) {
	local s = TB.DuelSpec(a), named = false
	foreach (p in TB.ParseWeapons(a)) if (!p.neg && !(("w" in p) && p.w.cat == "knife")) named = true
	if (!named) {
		s.ids = {}; foreach (e in TB.WPN) s.ids[e.id] <- 1
		s.cats = {}; foreach (cat, cv in TB.CAT_CV) s.cats[cat] <- 1
		s.give = null; s.disp = "один на один"; s.free <- true
	}
	s.foe <- bot.entindex()
	return s
}
TB.IsKnifeDuel <- function(s) { return s != null && s.give == null && s.cats.len() == 0 }
// дуэльное событие: нормальная версия при хорошем настроении, ножевые фразы — только на ножах
TB.DEv <- function(name, bot, ctx, spec = null, toxic = null) {
	if (spec == null) spec = TB.duel
	if (toxic == null) toxic = TB.IsToxic(bot)
	if (!toxic && ((name + "_nice") in TB_DATA.events)) return TBC.EventLine(name + "_nice", null, ctx)
	if (TB.IsKnifeDuel(spec) && ((name + "_knife") in TB_DATA.events) && TBC.Rnd() < 0.5) name += "_knife"
	return TBC.EventLine(name, null, ctx)
}
// есть ли у игрока оружие для дуэли (для ножей — всегда)
TB.HasDuelW <- function(p, d) {
	if (d.give == null) return true
	foreach (w in TB.Weapons(p)) { local id = TB.WId(w); if (id != "knife" && (id in d.ids)) return true }
	return false
}
// правила словами: «бомбу можно ставить», «без бомбы», «гранаты можно» -> { bomb, nades } / null
TB.DuelRules <- function(words) {
	local r = { bomb = null, nades = null }, any = false
	foreach (i, w in words) {
		local bomb = TB.Pre(w, "бомб") || w == "c4" || w == "с4" || TB.Pre(w, "плент") || TB.Pre(w, "плэнт") || TB.Pre(w, "став") || TB.Pre(w, "заклад") || TB.Pre(w, "плант")
		if (TB.Pre(w, "бомбит") || TB.Pre(w, "бомбан") || TB.Pre(w, "бомбил")) continue   // «меня бомбит» — не про бомбу
		local nade = TB.Pre(w, "гранат") || TB.Pre(w, "хаеш") || TB.Pre(w, "хеш") || TB.Pre(w, "граник")
		if (!bomb && !nade) continue
		local neg = false
		for (local j = (i > 3 ? i - 3 : 0); j < words.len() && j <= i + 2; j++) {
			local x = words[j]
			if (x == "без" || x == "нельзя" || TB.Pre(x, "запрещ") || (x == "не" && j + 1 < words.len() && words[j + 1] != "на")) neg = true
		}
		if (bomb) r.bomb = !neg
		else r.nades = !neg
		any = true
	}
	return any ? r : null
}
TB.RulesText <- function(r) {
	local parts = []
	if (r.bomb == true) parts.push("бомбу ставить можно")
	if (r.bomb == false) parts.push("без бомбы")
	if (r.nades == true) parts.push("гранаты можно")
	if (r.nades == false) parts.push("без гранат")
	local s = ""
	foreach (i, x in parts) s += (i > 0 ? ", " : "") + x
	return (s != "") ? s : "всё по-честному"
}
// применить правила к дуэли
TB.ApplyRules <- function(d, r) {
	if (r.bomb != null) d.bomb = r.bomb
	if (r.nades == true) { d.ids.hegrenade <- 1; d.cats.grenade <- 1; d.nades <- true }
	if (r.nades == false && d.give != "hegrenade") {
		if ("hegrenade" in d.ids) delete d.ids.hegrenade
		if ("grenade" in d.cats) delete d.cats.grenade
		if ("nades" in d) delete d.nades
	}
}
TB.DuelCtx <- function(ctx) {
	if (TB.duel != null) ctx.duel <- TB.duel.disp
	if (TB.duel != null && !("rules" in ctx && ctx.rules != "всё по-честному")) ctx.rules <- TB.RulesText({ bomb = TB.duel.bomb, nades = ("nades" in TB.duel) ? true : null })
	ctx.dirtyw <- (TB.dirtyW != "") ? TB.dirtyW : "со стволом"
	return ctx
}
TB.DuelOn <- function() { return TB.duel != null && TB.duel.active }

TB.DuelActivate <- function() {
	local d = TB.duel
	if (("free" in d) && TB.cvOrig != null) TB.DuelRestoreCv()   // один на один — ботам все стволы
	d.active = true
	d.round = TB.roundNo
	TB.giveNext = {}
	// бот-ИИ: разрешаем только нужный класс оружия (действует на всех ботов)
	if (TB_CFG.duel_scope == "all" && !("free" in d)) {
		// исходные квоты читаем ОДИН раз, пока дуэльные не применены. Команды консоли
		// выполняются только на следующем кадре: если перечитать сразу после «вернуть»,
		// прочитаются ещё дуэльные нули — и боты навсегда останутся с ножами.
		if (TB.cvOrig == null) {
			local orig = {}, any = false
			foreach (cat, cv in TB.CAT_CV) {
				local old = null
				try { old = Convars.GetInt(cv) } catch (e) {}
				orig[cv] <- (old == null) ? 1 : old
				if (orig[cv] != 0) any = true
			}
			// все нули — это хвост старой дуэли, а не настройка игрока
			if (!any) foreach (cv, v in orig) orig[cv] = 1
			TB.cvOrig = orig
			// карта сменится посреди дуэли — восстановим квоты при следующей загрузке
			local back = ""
			foreach (cv, v in orig) back += cv + " " + v + ";"
			try { StringToFile(TB.DUEL_FILE, back) } catch (e) {}
		}
		local cmd = ""
		foreach (cat, cv in TB.CAT_CV) cmd += cv + " " + ((cat in d.cats) ? 1 : 0) + ";"
		TB.SrvCmd(cmd)
	}
	TB.DuelEnforce(true)
	// у игрока нет нужного ствола (не купил / не было денег) — кладём под ноги
	if (d.give != null) TB.Later(1.0, function() {
		local h = TB.Human()
		if (TB.duel == null || !TB.duel.active || h == null || !TB.Alive(h) || TB.HasDuelW(h, TB.duel)) return
		try { TB.SpawnWeapon(TB.duel.give, h.GetOrigin() + Vector(0, 0, 16)) } catch (e) {}
	})
}
// вернуть квоты оружия ботам (d не нужен — исходные значения общие)
TB.cvOrig <- null
TB.DuelRestoreCv <- function(d = null) {
	if (TB.cvOrig == null) return
	local cmd = ""
	foreach (cv, v in TB.cvOrig) cmd += cv + " " + v + ";"
	TB.cvOrig = null
	TB.SrvCmd(cmd)
	try { StringToFile(TB.DUEL_FILE, "") } catch (e) {}
}
// аварийно: всем ботам снова все стволы (!tb duel, «чё вы все на ножах»)
TB.AllWeapons <- function() {
	TB.cvOrig = null
	local cmd = ""
	foreach (cat, cv in TB.CAT_CV) cmd += cv + " 1;"
	TB.SrvCmd(cmd)
	try { StringToFile(TB.DUEL_FILE, "") } catch (e) {}
}
TB.DuelStop <- function() {
	local d = TB.duel
	TB.duel = null
	TB.DuelRestoreCv(d)
}
// перенести на следующий раунд (не купил, нет денег, «давай в следующем»)
TB.DuelPostpone <- function() {
	local d = TB.duel
	if (d == null) return
	if (d.active) { TB.DuelRestoreCv(d); d.active = false; d.round = -1 }
	d.arm = 0.0
}
// поменять оружие / правила уже договорённой дуэли
TB.DuelReplace <- function(spec) {
	local d = TB.duel, was = d.active
	d.ids = spec.ids; d.give = spec.give; d.disp = spec.disp; d.cats = spec.cats; d.bomb = spec.bomb
	foreach (k in ["nades", "free", "foe"]) { if (k in spec) d[k] <- spec[k]; else if (k in d) delete d[k] }
	if (was) TB.DuelActivate()   // новые квоты поверх, исходные (TB.cvOrig) не трогаем
}
TB.DUEL_FILE <- "toxicbots_duel.txt"
TB.duelChecked <- false
TB.DuelRecover <- function() {
	if (TB.duelChecked) return
	TB.duelChecked = true
	local s = null
	try { s = FileToString(TB.DUEL_FILE) } catch (e) {}
	if (s == null || s.len() < 5 || s.find("bot_allow") != 0) return
	// старые версии мода могли записать сюда нули — тогда просто разрешаем всё
	if (s.find(" 1;") == null) { TB.AllWeapons(); printl("[ToxicBots] вернул ботам все стволы"); return }
	TB.SrvCmd(s)
	try { StringToFile(TB.DUEL_FILE, "") } catch (e) {}
	printl("[ToxicBots] восстановил квоты оружия ботов после прошлой дуэли")
}
// боты, на которых действует дуэль
TB.DuelBots <- function() {
	local h = TB.Human()
	if (TB_CFG.duel_scope == "all" || h == null) return TB.Bots()
	return TB.Bots(h.GetTeam() == 2 ? 3 : 2)
}
// отобрать лишнее, выдать разрешённое, вернуть деньги
TB.DuelEnforce <- function(now = false) {
	local d = TB.duel, t = Time()
	if ("free" in d) return
	foreach (b in TB.DuelBots()) {
		if (!TB.Alive(b)) continue
		local has = false
		foreach (w in TB.Weapons(b)) {
			local id = TB.WId(w)
			if (id == "knife") continue
			if (id == "c4") { if (!d.bomb) TB.KillEnt(w); continue }   // «без бомбы»
			if (id in d.ids) { has = true; continue }
			TB.KillEnt(w)
		}
		local i = b.entindex()
		// выдаём не больше 3 раз за раунд (если бот почему-то не подбирает — не мусорим)
		if (d.give != null && !has && (!(i in TB.giveNext) || (t >= TB.giveNext[i][0] && TB.giveNext[i][1] < 3))) {
			TB.giveNext[i] <- [t + 3.0, (i in TB.giveNext) ? TB.giveNext[i][1] + 1 : 1]
			try { TB.SpawnWeapon(d.give, b.GetOrigin() + Vector(0, 0, 16)) } catch (e) {}
		}
		if (i in TB.money) {
			try { if (NetProps.GetPropInt(b, "m_iAccount") < TB.money[i]) NetProps.SetPropInt(b, "m_iAccount", TB.money[i]) } catch (e) {}
		}
	}
}
TB.SnapMoney <- function() {
	TB.money = {}
	foreach (b in TB.Bots()) try { TB.money[b.entindex()] <- NetProps.GetPropInt(b, "m_iAccount") } catch (e) {}
}

// согласиться на дуэль (сейчас или со следующего раунда)
// сразу — только если у игрока уже есть нужный ствол (или ножи); иначе ждём, пока купит,
// а не успел — со следующего раунда (там выдадим)
TB.StartDuel <- function(spec, bot, human, evNow, evNext, forceNext = false) {
	TB.duel = { ids = spec.ids, give = spec.give, disp = spec.disp, cats = spec.cats, bomb = spec.bomb,
		active = false, round = -1, arm = 0.0, armBot = bot.entindex() }
	foreach (k in ["nades", "free", "foe"]) if (k in spec) TB.duel[k] <- spec[k]
	TB.offerNextRound = TB.Max(TB.offerNextRound, TB.roundNo + 4)
	local ctx = TB.DuelCtx(TB.Ctx(human, bot))
	local inWin = Time() - TB.roundStartT < TB_CFG.duel_start_window
	// мёртвый бот «сейчас» не согласится — со следующего раунда
	if (!forceNext && !TB.Alive(bot)) { forceNext = true; evNext = "duel_accept_dead" }
	if (!forceNext && inWin && TB.HasDuelW(human, TB.duel)) {
		TB.DuelActivate()
		TB.BotSay(bot, TB.DEv(evNow, bot, ctx), false)
	} else if (!forceNext && inWin && TB.Alive(human)) {
		TB.duel.arm = TB.roundStartT + TB_CFG.duel_start_window + 10.0
		TB.BotSay(bot, TB.DEv("duel_accept_buy", bot, ctx), false)
	} else TB.BotSay(bot, TB.DEv(evNext, bot, ctx, null, true), false)
	TB.Talked(bot)
}
// think: игрок докупил оружие для дуэли
TB.DuelArmTick <- function(now) {
	local d = TB.duel
	if (d == null || d.active || d.arm <= 0.0) return
	if (now > d.arm) { d.arm = 0.0; return }   // не успел — начнём со следующего раунда
	local h = TB.Human()
	if (h == null || !TB.HasDuelW(h, d)) return
	TB.DuelActivate()
	local b = PlayerInstanceFromIndex(d.armBot)
	if (b == null || !b.IsValid() || !TB.IsBot(b)) { local all = TB.Bots(); if (all.len() == 0) return; b = TBC.Pick(all) }
	TB.BotSay(b, TB.DEv("duel_bought", b, TB.DuelCtx(TB.Ctx(h, b))), false)
}

TB.OnDuel <- function(human, a, rude, polite) {
	local bot = TB.AliveFoe(a, human)
	if (bot == null) return
	local spec = TB.IsOneVOne(TB.Words(a)) ? TB.OneVOneSpec(bot, a) : TB.DuelSpec(a)
	local ctx = TB.Ctx(human, bot)
	ctx.duel <- spec.disp
	TB.DuelCtx(ctx)
	ctx.duel = spec.disp
	local r = TB.DuelRules(TB.Words(a))
	ctx.rules = (r != null) ? TB.RulesText(r) : "всё по-честному"
	TB.Talked(bot)
	if (TB.duel != null) { ctx.duel = TB.duel.disp; TB.BotSay(bot, TBC.EventLine("duel_already", null, ctx), false); return }
	// кидал на дуэли недавно (2 раунда) — чаще отказывают; потом почти забывают
	local fresh = TB.roundNo - TB.dirtyRound <= 2
	if (TB.dirty > 0 && TBC.Rnd() < (fresh ? 0.4 + 0.1 * TB.dirty : 0.12)) { TB.BotSay(bot, TBC.EventLine("duel_refuse_dirty", null, ctx), false); return }
	if ((rude && TBC.Rnd() < 0.45) || (TB.resp < 25 && TBC.Rnd() < 0.4)) { TB.BotSay(bot, TBC.EventLine("duel_refuse", null, ctx), false); return }
	TB.offer = null
	TB.StartDuel(spec, bot, human, "duel_accept", "duel_accept_next")
	if (r != null) TB.BotSay(bot, TBC.EventLine("duel_rule_ok", null, TB.DuelCtx(ctx)), false)
}

// бот сам предлагает дуэль в начале раунда
TB.MaybeOffer <- function() {
	if (TB.duel != null || TB.offer != null || TB.roundNo < 2 || TB.roundNo < TB.offerNextRound || TBC.Rnd() > TB_CFG.duel_offer_chance) return
	local h = TB.Human()
	if (h == null || h.GetTeam() < 2) return
	local foes = TB.Bots(h.GetTeam() == 2 ? 3 : 2)
	if (foes.len() == 0) return
	local b = TBC.Pick(foes)
	// чаще ножи, иногда пистолеты/AWP
	local r = TBC.Rnd(), spec
	local fake = { toks = [TBC.Decode(r < 0.6 ? "нож" : (r < 0.8 ? "дигл" : (r < 0.9 ? "авп" : "скаут")))] }
	spec = TB.DuelSpec(fake)
	local ctx = TB.Ctx(h, b)
	ctx.duel <- spec.disp
	// предложение действует только после того, как появилось в чате (и если вообще влезло)
	if (!TB.BotSay(b, TBC.EventLine("duel_offer", null, ctx), false, 2.5)) return
	local shown = TB.botNext[b.entindex()] - 0.5
	TB.offerNextRound = TB.roundNo + 3
	TB.offer = { spec = spec, bot = b.entindex(), from = shown, until = shown + 45.0 }
}
TB.YES <- {}
TB.NO <- {}
foreach (w in ["да", "го", "гоу", "давай", "давайте", "ок", "окей", "ok", "okay", "погнали", "конечно", "ладно", "согласен", "изи", "лады", "хорошо", "можно", "угу", "ага", "дa", "yes", "+", "плюс", "принято", "погнали", "заебись", "камон", "давай-давай"])
	TB.YES[w] <- 1
foreach (w in ["нет", "не", "неа", "нее", "отстань", "отъебись", "потом", "no", "нах", "нахуй", "пох", "похуй", "лень", "не хочу", "-", "отвали", "неохота"])
	TB.NO[w] <- 1
// короткий ответ «да/нет» на предложение бота: 1 / -1 / 0
TB.YesNo <- function(a, text) {
	if (a.toks.len() > 4) return 0
	local t = TB.Trim(text)
	if (t == "+" || t == "++" || t == "+++") return 1
	if (t == "-") return -1
	foreach (w in TB.Words(a)) {
		if (w in TB.NO) return -1
		if (w in TB.YES) return 1
	}
	return 0
}

// ------------------------------------------------------------ бомба (для «заложил — охраняйте» и «дуэль без бомбы»)
TB_Events.OnGameEvent_bomb_planted <- function(params) {
	TB.bombPlanted = true
	if (!TB_CFG.enabled || !TB.DuelOn() || TB.duel.bomb || !("userid" in params)) return
	local p = TB.NoteUid(params.userid)
	if (p == null || TB.IsBot(p)) return
	// договорились «без бомбы», а игрок заложил
	TB.dirty++
	TB.dirtyW = "с бомбой"; TB.dirtyDisp = TB.duel.disp; TB.dirtyT = Time(); TB.dirtyBot = -1
	TB.Respect(-10)
	local foes = TB.Bots(p.GetTeam() == 2 ? 3 : 2)
	if (foes.len() == 0) return
	local b = TBC.Pick(foes)
	TB.prio = true; TB.tag = "dirty"
	TB.BotSay(b, TBC.EventLine("duel_dirty_bomb", null, TB.DuelCtx(TB.Ctx(p, b))), false, 0.5)
	TB.prio = false; TB.tag = null
}
TB_Events.OnGameEvent_bomb_defused <- function(params) { TB.bombPlanted = false }
TB_Events.OnGameEvent_bomb_exploded <- function(params) { TB.bombPlanted = false }
