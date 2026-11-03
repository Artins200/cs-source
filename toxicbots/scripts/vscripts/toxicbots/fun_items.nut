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
// найти оружие в тексте: { w = запись TB.WPN } / { c = запись TB.WCAT } / null
TB.ParseWeapon <- function(a) {
	local words = TB.Words(a)
	foreach (w in words) {
		foreach (c in TB.WCAT) foreach (k in c.keys) if (TB.Pre(w, k)) return { c = c }
		foreach (e in TB.WPN) {
			if ("exact" in e) foreach (k in e.exact) if (w == k) return { w = e }
			foreach (k in e.keys) if (TB.Pre(w, k)) return { w = e }
		}
	}
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
TB.offer <- null       // бот предложил дуэль: { spec, bot, until }
TB.roundStartT <- -100.0
TB.roundNo <- 0
TB.money <- {}         // деньги ботов на начало раунда (дуэль не должна их разорять)
TB.giveNext <- {}

TB.DuelSpec <- function(a) {
	local p = TB.ParseWeapon(a)
	local s = { ids = { knife = 1 }, give = null, disp = "на ножах", cats = {} }
	if (p == null) return s
	if ("w" in p) {
		s.ids[p.w.id] <- 1
		s.give = (p.w.cat == "knife") ? null : p.w.id
		s.disp = p.w.pl
		if (p.w.cat != "knife") s.cats[p.w.cat] <- 1
	} else {
		foreach (e in TB.WPN) if (e.cat == p.c.cat) s.ids[e.id] <- 1
		s.give = p.c.give
		s.disp = p.c.pl
		s.cats[p.c.cat] <- 1
	}
	return s
}
TB.DuelCtx <- function(ctx) {
	if (TB.duel != null) ctx.duel <- TB.duel.disp
	ctx.dirtyw <- (TB.dirtyW != "") ? TB.dirtyW : "со стволом"
	return ctx
}
TB.DuelOn <- function() { return TB.duel != null && TB.duel.active }

TB.DuelActivate <- function() {
	local d = TB.duel
	d.active = true
	d.round = TB.roundNo
	TB.giveNext = {}
	// бот-ИИ: разрешаем только нужный класс оружия (действует на всех ботов)
	if (TB_CFG.duel_scope == "all") {
		d.cv <- {}
		local cmd = ""
		foreach (cat, cv in TB.CAT_CV) {
			local old = null
			try { old = Convars.GetInt(cv) } catch (e) {}
			d.cv[cv] <- (old == null) ? 1 : old
			cmd += cv + " " + ((cat in d.cats) ? 1 : 0) + ";"
		}
		// карта сменится посреди дуэли — восстановим квоты при следующей загрузке
		local back = ""
		foreach (cv, v in d.cv) back += cv + " " + v + ";"
		try { StringToFile(TB.DUEL_FILE, back) } catch (e) {}
		TB.SrvCmd(cmd)
	}
	TB.DuelEnforce(true)
}
TB.DuelStop <- function() {
	local d = TB.duel
	TB.duel = null
	if (d == null || !("cv" in d)) return
	local cmd = ""
	foreach (cv, v in d.cv) cmd += cv + " " + v + ";"
	TB.SrvCmd(cmd)
	try { StringToFile(TB.DUEL_FILE, "") } catch (e) {}
}
TB.DUEL_FILE <- "toxicbots_duel.txt"
TB.duelChecked <- false
TB.DuelRecover <- function() {
	if (TB.duelChecked) return
	TB.duelChecked = true
	local s = null
	try { s = FileToString(TB.DUEL_FILE) } catch (e) {}
	if (s == null || s.len() < 5 || s.find("bot_allow") != 0) return
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
	foreach (b in TB.DuelBots()) {
		if (!TB.Alive(b)) continue
		local has = false
		foreach (w in TB.Weapons(b)) {
			local id = TB.WId(w)
			if (id == "knife" || id == "c4") continue
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
TB.StartDuel <- function(spec, bot, human, evNow, evNext) {
	TB.duel = { ids = spec.ids, give = spec.give, disp = spec.disp, cats = spec.cats, active = false, round = -1 }
	local ctx = TB.DuelCtx(TB.Ctx(human, bot))
	if (Time() - TB.roundStartT < TB_CFG.duel_start_window) {
		TB.DuelActivate()
		TB.BotSay(bot, TB.Ev(evNow, bot, ctx), false)
	} else TB.BotSay(bot, TBC.EventLine(evNext, null, ctx), false)
	TB.Talked(bot)
}

TB.OnDuel <- function(human, a, rude, polite) {
	local spec = TB.DuelSpec(a)
	local bot = TB.PickBot(a, human, false)
	if (bot == null) return
	local ctx = TB.Ctx(human, bot)
	ctx.duel <- spec.disp
	TB.DuelCtx(ctx)
	ctx.duel = spec.disp
	TB.Talked(bot)
	if (TB.duel != null) { ctx.duel = TB.duel.disp; TB.BotSay(bot, TBC.EventLine("duel_already", null, ctx), false); return }
	if (TB.dirty > 0 && TBC.Rnd() < 0.55 + 0.15 * TB.dirty) { TB.BotSay(bot, TBC.EventLine("duel_refuse_dirty", null, ctx), false); return }
	if ((rude && TBC.Rnd() < 0.45) || (TB.resp < 25 && TBC.Rnd() < 0.4)) { TB.BotSay(bot, TBC.EventLine("duel_refuse", null, ctx), false); return }
	TB.offer = null
	TB.StartDuel(spec, bot, human, "duel_accept", "duel_accept_next")
}

// бот сам предлагает дуэль в начале раунда
TB.MaybeOffer <- function() {
	if (TB.duel != null || TB.offer != null || TB.roundNo < 2 || TBC.Rnd() > TB_CFG.duel_offer_chance) return
	local h = TB.Human()
	if (h == null || h.GetTeam() < 2) return
	local foes = TB.Bots(h.GetTeam() == 2 ? 3 : 2)
	if (foes.len() == 0) return
	local b = TBC.Pick(foes)
	// чаще ножи, иногда пистолеты/AWP
	local r = TBC.Rnd(), spec
	local fake = { toks = [TBC.Decode(r < 0.6 ? "нож" : (r < 0.8 ? "дигл" : (r < 0.9 ? "авп" : "скаут")))] }
	spec = TB.DuelSpec(fake)
	TB.offer = { spec = spec, bot = b.entindex(), until = Time() + 45.0 }
	local ctx = TB.Ctx(h, b)
	ctx.duel <- spec.disp
	TB.BotSay(b, TBC.EventLine("duel_offer", null, ctx), false, 2.5)
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
