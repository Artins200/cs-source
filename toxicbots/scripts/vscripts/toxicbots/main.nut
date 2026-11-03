// =====================================================================
//  ToxicBots для Counter-Strike: Source (VScript, без SourceMod)
//  Боты отвечают на твой чат/голос, ноют, когда сливают, и ищут худшего.
// =====================================================================
IncludeScript("toxicbots/config")
IncludeScript("toxicbots/data")
IncludeScript("toxicbots/core")

if (!("TB" in getroottable())) ::TB <- {}
TB.queue <- []          // отложенные сообщения/действия
TB.stats <- {}          // entindex -> статистика
TB.botNext <- {}        // entindex бота -> когда может писать снова
TB.lastBot <- null      // entindex бота, с которым "разговор"
TB.lastBotTime <- -100.0
TB.roundDeath <- false
TB.matchOver <- false
TB.greeted <- false
TB.voiceSeq <- -1
TB.thinker <- null
TB.nextVoice <- 0.0
TB.voiceLast <- null    // прошлое содержимое файла голоса (не разбираем одно и то же)
TB.voiceMiss <- 0       // сколько раз подряд файла голоса нет
TB.uid <- {}            // entindex -> userid (для радио-команд)
TB.temper <- {}         // entindex бота -> характер 0 (душка) .. 1 (токсик)
TB.resp <- TB_CFG.start_respect   // как боты относятся к тебе: 0 — ненавидят, 100 — уважают
TB.peaceUntil <- -100.0 // «давайте командой» — боты добрее до этого времени
TB.sandbag <- null      // { state = "claimed"|"proven"|"failed", ck, cd, rounds }

// ------------------------------------------------------------ игроки
TB.Players <- function() {
	local out = [], mx = MaxClients().tointeger()
	for (local i = 1; i <= mx; i++) {
		local p = PlayerInstanceFromIndex(i)
		if (p != null && p.IsValid()) out.push(p)
	}
	return out
}
TB.IsBot <- function(p) { return IsPlayerABot(p) }
TB.Name <- function(p) {
	local n = NetProps.GetPropString(p, "m_szNetname")
	return (n == null || n == "") ? "Игрок" : n
}
TB.Alive <- function(p) { return NetProps.GetPropInt(p, "m_lifeState") == 0 }
TB.Bots <- function(team = 0) {
	local out = []
	foreach (p in TB.Players()) if (TB.IsBot(p) && p.GetTeam() >= 2 && (team == 0 || p.GetTeam() == team)) out.push(p)
	return out
}
TB.Humans <- function() {
	local out = []
	foreach (p in TB.Players()) if (!TB.IsBot(p)) out.push(p)
	return out
}

// ------------------------------------------------------------ статистика
TB.St <- function(uid) {
	if (!(uid in TB.stats))
		TB.stats[uid] <- { k = 0, d = 0, dmg = 0, hs = 0, tk = 0, rk = 0, rd = 0, rdmg = 0, killedMe = 0, name = "" }
	return TB.stats[uid]
}
TB.ResetRound <- function() { foreach (s in TB.stats) { s.rk = 0; s.rd = 0; s.rdmg = 0 } TB.roundDeath = false }
TB.ResetMatch <- function() {
	TB.stats = {}; TB.matchOver = false; TB.sandbag = null; TB.resp = TB_CFG.start_respect
	if ("worstRow" in TB) { TB.worstRow = {}; TB.roundNo = 0; TB.kickNextRound = 0; TB.offer = null }
	if (("duel" in TB) && TB.duel != null) TB.DuelStop()
}
TB.NoteUid <- function(userid) {
	local p = GetPlayerFromUserID(userid)
	if (p != null) TB.uid[p.entindex()] <- userid
	return p
}

TB.TeamScore <- function(team) {
	local e = null
	while ((e = Entities.FindByClassname(e, "cs_team_manager")) != null)
		if (NetProps.GetPropInt(e, "m_iTeamNum") == team) return NetProps.GetPropInt(e, "m_iScore")
	return 0
}

// контекст для шаблонов: human — игрок, bot — кто говорит
TB.Ctx <- function(human, bot) {
	local hs = (human != null) ? TB.St(human.entindex()) : TB.St(-1)
	local bs = (bot != null) ? TB.St(bot.entindex()) : TB.St(-1)
	local ctx = {
		name = (human != null) ? TB.Name(human) : "Игрок",
		bot = (bot != null) ? TB.Name(bot) : "Бот",
		k = hs.k, d = hs.d, kd = hs.k + "-" + hs.d,
		map = GetMapName(),
		weapon = ("weapon" in TB) ? TB.weapon : "ствол",
		num = (bs.killedMe > 0) ? bs.killedMe : 1,
		score = TB.TeamScore(2) + ":" + TB.TeamScore(3),
		target = (human != null) ? TB.Name(human) : "Игрок"
	}
	ctx.perf <- TBC.Expand((hs.k <= hs.d) ? "{perf_bad}" : "{perf_good}", ctx)
	ctx.bk <- bs.k; ctx.bd <- bs.d; ctx.bkd <- bs.k + "-" + bs.d
	ctx.rk <- hs.rk
	ctx.ck <- (TB.sandbag != null) ? TB.sandbag.ck : 0
	ctx.cd <- (TB.sandbag != null) ? TB.sandbag.cd : 0
	ctx.cmd <- "иду"; ctx.site <- "плент"
	ctx.tkd <- ctx.bkd; ctx.duel <- "на ножах"; ctx.dirtyw <- "со стволом"
	ctx.cmdwhere <- "идти туда"; ctx.wname <- "ствол"; ctx.have <- "ствол"
	return ctx
}

// ------------------------------------------------------------ настроение
TB.Clamp <- function(v, a, b) { return v < a ? a : (v > b ? b : v) }
TB.Temper <- function(bot) {
	local i = bot.entindex()
	if (!(i in TB.temper)) TB.temper[i] <- TB.Clamp(TB_CFG.toxicity + RandomFloat(-0.3, 0.3), 0.0, 1.0)
	return TB.temper[i]
}
TB.Respect <- function(d) { TB.resp = TB.Clamp(TB.resp + d, 0, 100) }
// вероятность, что бот ответит токсично
TB.ToxicP <- function(bot, rude = false, polite = false, mat = false) {
	local p = TB.Temper(bot) + (50 - TB.resp) / 100.0
	if (rude) p += 0.45
	else if (mat) p += 0.1
	if (polite) p -= 0.25
	if (Time() < TB.peaceUntil) p -= 0.35
	return TB.Clamp(p, 0.03, 0.97)
}
TB.IsToxic <- function(bot, rude = false, polite = false, mat = false) { return TBC.Rnd() < TB.ToxicP(bot, rude, polite, mat) }
// строка события с учётом настроения бота (round_lost -> round_lost_nice)
TB.Ev <- function(name, bot, ctx, side = null, toxic = null) {
	if (toxic == null) toxic = TB.IsToxic(bot)
	if (!toxic && ((name + "_nice") in TB_DATA.events)) name = name + "_nice"
	return TBC.EventLine(name, side, ctx)
}

// ------------------------------------------------------------ вывод в чат
TB.Clean <- function(s) {
	local out = ""
	for (local i = 0; i < s.len(); i++) {
		local c = s[i]
		if (c == '%' || c == '\n' || c == '\r' || (c >= 1 && c <= 8)) continue
		out += c.tochar()
	}
	while (out.len() > 0 && out[0] == '#') out = out.slice(1)
	return out
}

// режем длинные сообщения по пробелам (лимит пакета чата ~250 байт)
TB.Split <- function(s, lim = 170) {
	local out = []
	while (s.len() > lim) {
		local cut = lim
		while (cut > 40 && s[cut] != ' ') cut--
		if (cut <= 40) cut = lim
		while (cut > 0 && (s[cut] & 0xC0) == 0x80) cut--  // не рвём UTF-8 символ
		out.push(s.slice(0, cut))
		s = s.slice(cut)
		while (s.len() > 0 && s[0] == ' ') s = s.slice(1)
	}
	if (s.len() > 0) out.push(s)
	return out
}

// мгновенно напечатать от имени бота (как обычный чат CS:S)
TB.Print <- function(bot, text, teamOnly) {
	if (bot == null || !bot.IsValid()) return
	local team = bot.GetTeam()
	local color = (team == 2) ? "FF4040" : ((team == 3) ? "99CCFF" : "CCCCCC")
	local head = "\x01"
	if (!TB.Alive(bot)) head += "*УБИТ* "
	if (teamOnly) head += (team == 2) ? "(Террорист) " : "(Спецназ) "
	head += "\x07" + color + TB.Clean(TB.Name(bot)) + "\x01 :  "
	local seen = false, host = TB.Human()
	foreach (part in TB.Split(TB.Clean(text))) {
		foreach (h in TB.Humans()) {
			if (teamOnly && h.GetTeam() != team && h.GetTeam() >= 2) continue
			ClientPrint(h, 3, head + part)   // 3 = HUD_PRINTTALK
			if (host != null && h.entindex() == host.entindex()) seen = true
		}
	}
	return seen
}

// ------------------------------------------------------------ озвучка
// готовые клипы: sound/toxicbots/<имя>.wav (записаны заранее)
TB.CLIPS <- ["lose1", "lose2", "lose3", "lose4", "matchlose1", "win1", "win2", "win3", "matchwin1", "kill1"]
TB.PrecacheClips <- function() {
	foreach (c in TB.CLIPS) PrecacheSound("toxicbots/" + c + ".wav")
}
TB.PlayClip <- function(bot, name) {
	if (!TB_CFG.clips_enabled) return
	EmitSoundEx({ sound_name = "toxicbots/" + name + ".wav", entity = bot, channel = 0,
		volume = TB_CFG.clips_volume, sound_level = 0, filter_type = 5 })   // 0 = слышно везде, 5 = всем
}

// живая озвучка остальных фраз: программа voice/ЗАПУСТИТЬ_ГОЛОС.bat читает этот файл и говорит голосом бота
TB.ttsLines <- []
TB.ttsSeq <- 0
TB.ttsSession <- RandomInt(1, 999999999)
TB.Tts <- function(bot, text) {
	if (!TB_CFG.tts_enabled) return
	TB.ttsSeq++
	TB.ttsLines.push(TB.ttsSession + ":" + TB.ttsSeq + "\t" + bot.entindex() + "\t" + bot.GetTeam() + "\t" + text)
	if (TB.ttsLines.len() > 15) TB.ttsLines.remove(0)
	local s = ""
	foreach (l in TB.ttsLines) s += l + "\n"
	StringToFile(TB_CFG.tts_file, s)
}

// think спит, пока нет дел; если появилось дело раньше — будим
TB.thinkAt <- 0.0
TB.Push <- function(item) {
	TB.queue.push(item)
	if (TB.thinker != null && TB.thinker.IsValid() && item.t < TB.thinkAt - 0.05) {
		AddThinkToEnt(TB.thinker, "TB_Think")
		TB.thinkAt = Time() + 0.1
	}
}
TB.Later <- function(delay, fn) { TB.Push({ t = Time() + delay, f = fn }) }

// бот "печатает" (задержка по длине) и отправляет
TB.BotSay <- function(bot, text, teamOnly, extra = 0.0, raw = false) {
	if (bot == null || text == null || text == "") return
	local snd = ""
	if (text[0] == 2) {
		local e = text.find("\x02", 1)
		if (e != null) { snd = text.slice(1, e); text = text.slice(e + 1) }
	}
	local more = []
	if (!raw && snd == "") { local hz = TB.Humanize(text); text = hz[0]; more = hz[1] }
	local idx = bot.entindex(), now = Time()
	local typing = 0.6 + (text.len() / 2.0) / TB_CFG.typing_speed
	if (typing > 4.5) typing = 4.5
	local t = now + extra + typing + RandomFloat(0.0, 0.6)
	if ((idx in TB.botNext) && TB.botNext[idx] > t) t = TB.botNext[idx] + 0.8
	TB.botNext[idx] <- t + 0.5
	TB.Push({ t = t, f = function() {
		local b = PlayerInstanceFromIndex(idx)
		if (b != null && b.IsValid() && TB.IsBot(b)) {
			local seen = TB.Print(b, text, teamOnly)
			if (seen && snd != "") TB.PlayClip(b, snd)
			else if (seen) TB.Tts(b, text)
		}
	} })
	if (TB_CFG.debug) printl("[ToxicBots] " + TB.Name(bot) + (teamOnly ? " (team)" : "") + ": " + text)
	// вторая часть / исправление опечатки — отдельным сообщением следом
	foreach (x in more) if (x != "") TB.BotSay(bot, x, teamOnly, 0.0, true)
}

// ------------------------------------------------------------ think
TB.Tick <- function() {
	local now = Time()
	if (TB.queue.len() > 0) {
		local due = [], rest = []
		foreach (q in TB.queue) { if (q.t <= now) due.push(q); else rest.push(q) }
		TB.queue = rest
		foreach (q in due) { try { q.f() } catch (e) { printl("[ToxicBots] ошибка: " + e) } }
	}
	if (TB_CFG.voice_enabled && now >= TB.nextVoice) {
		try { TB.PollVoice() } catch (e) { printl("[ToxicBots] голос: " + e) }
		// программы голоса нет -> проверяем файл раз в 3 с, есть -> 4 раза в секунду
		TB.nextVoice = now + ((TB.voiceMiss > 8) ? 3.0 : TB_CFG.voice_poll)
	}
	// просыпаемся только когда есть дело: ближайшее сообщение или проверка голоса
	local next = TB_CFG.voice_enabled ? TB.nextVoice : now + 2.0
	foreach (q in TB.queue) if (q.t < next) next = q.t
	local ft = null
	try { ft = TB.FunTick(now) } catch (e) { printl("[ToxicBots] ошибка: " + e) }
	if (ft != null && now + ft < next) next = now + ft
	local dt = TB.Clamp(next - now, 0.1, 2.0)
	TB.thinkAt = now + dt
	return dt
}

TB.EnsureThink <- function() {
	if (TB.thinker != null && TB.thinker.IsValid()) return
	local e = SpawnEntityFromTable("info_target", { targetname = "toxicbots_think" })
	if (e == null) return
	e.ValidateScriptScope()
	e.GetScriptScope().TB_Think <- function() { return ::TB.Tick() }
	AddThinkToEnt(e, "TB_Think")
	TB.thinker = e
	TB.thinkAt = Time() + 0.1
}

// ------------------------------------------------------------ ответ на твой чат/голос
TB.TEAM_INTENTS <- { tactics = 1, blame_team = 1, lost = 1 }

TB.FindMentioned <- function(toks, bots) {
	foreach (b in bots) {
		local nt = TBC.Tokenize(TBC.Variants(TB.Name(b))[0]).toks
		foreach (t in toks) {
			if (t.len() < 3) continue
			foreach (n in nt) if (n.len() >= 3 && TBC.PartScore(n, 1, t) >= 1.0) return b
		}
	}
	return null
}

// выбрать бота, к которому обращаются: по нику -> с кем недавно говорили -> из нужной стороны
TB.PickBot <- function(a, human, wantTeam) {
	local ht = human.GetTeam(), all = TB.Bots()
	if (all.len() == 0) return null
	local bot = TB.FindMentioned(a.toks, all)
	if (bot == null && TB.lastBot != null && Time() - TB.lastBotTime < 20.0 && TBC.Rnd() < 0.5) {
		local lb = PlayerInstanceFromIndex(TB.lastBot)
		if (lb != null && lb.IsValid() && TB.IsBot(lb)) bot = lb
	}
	if (bot != null) return bot
	local mates = [], foes = []
	foreach (b in all) { if (b.GetTeam() == ht) mates.push(b); else foes.push(b) }
	local pool = wantTeam ? mates : foes
	if (pool.len() == 0) pool = wantTeam ? foes : mates
	return pool.len() > 0 ? TBC.Pick(pool) : null
}
TB.Side <- function(bot, human) { return (bot.GetTeam() == human.GetTeam()) ? "team" : "enemy" }
TB.Talked <- function(bot) { TB.lastBot = bot.entindex(); TB.lastBotTime = Time() }

// как сообщение влияет на отношение ботов к тебе
TB.MOOD <- { praise = 6, love = 5, sorry = 8, polite = 5, greet = 2, team_up = 8,
	kd_taunt = -3, cheater = -3, ggez = -4, threat = -2, blame_team = -4, mother = -6 }
TB.UpdateMood <- function(a, rude, polite) {
	local d = 0
	if (rude) d -= 10
	if (polite) d += 4
	if (a.intent != null && (a.intent.name in TB.MOOD)) d += TB.MOOD[a.intent.name]
	TB.Respect(d)
}

TB.OnHumanSay <- function(human, text) {
	if (!TB_CFG.enabled) return
	if (TB.Bots().len() == 0) return
	local a = TBC.Analyze(text)
	local rudeWord = TBC.RudeWord(a), polite = TBC.IsPolite(a.toks)
	local rude = rudeWord != null
	a.rudeWord <- (rudeWord != null) ? rudeWord : ""
	TB.UpdateMood(a, rude, polite)
	local name = (a.intent != null) ? a.intent.name : ""
	if (TB_CFG.debug) printl("[ToxicBots] \"" + text + "\" -> " + name + " (" + a.score + ") хамство=" + rude + " вежливо=" + polite + " уважение=" + TB.resp)

	if (TB.FunSay(human, a, text, rude, polite, name)) return
	if (name in TB.CMDS) { TB.OnCommand(human, a, name, rude, polite); return }
	if (name == "team_up") { TB.OnTeamUp(human, a, rude, polite); return }
	if (name == "kd_taunt") { TB.OnKdTaunt(human, a, rude, polite); return }
	if (name == "sandbag") { TB.OnSandbag(human, a, rude, polite); return }

	if (TBC.Rnd() > TB_CFG.reply_chance) return
	local wantTeam = (name in TB.TEAM_INTENTS) ? TBC.Rnd() < 0.85 : TBC.Rnd() > TB_CFG.enemy_share
	local bot = TB.PickBot(a, human, wantTeam)
	if (bot == null) return
	local side = TB.Side(bot, human)
	local toxic = TB.IsToxic(bot, rude, polite, a.mat)
	local r = TBC.Reply(a, side, TB.Ctx(human, bot), !toxic)
	if (TB_CFG.debug) printl("[ToxicBots]   " + TB.Name(bot) + " -> " + r[1] + " слово=" + a.word)
	TB.BotSay(bot, r[0], false)
	TB.Talked(bot)
	TB.FunAfterReply(human, bot, a, rude, toxic)

	// второй бот подтявкивает
	local all = TB.Bots()
	if (all.len() > 1 && TBC.Rnd() < (toxic ? TB_CFG.pile_chance : TB_CFG.pile_chance * 0.4)) {
		local other = bot
		for (local n = 0; n < 5 && other.entindex() == bot.entindex(); n++) other = TBC.Pick(all)
		if (other.entindex() != bot.entindex()) TB.BotSay(other, TB.Ev("pile", other, TB.Ctx(human, other), null, toxic), false, 1.5)
	}
}

// ------------------------------------------------------------ приказы тиммейтам (через радио игры)
// slot = номер радио-команды в CS:S (RadioType): боты реагируют на неё как на Z/X/C
TB.CMDS <- {
	cmd_follow = { slot = 6,  snd = "Radio.FollowMe",      say = "За мной!",            cmd = "иду за тобой" },
	cmd_cover  = { slot = 2,  snd = "Radio.CoverMe",       say = "Прикройте меня!",     cmd = "прикрываю" },
	cmd_hold   = { slot = 4,  snd = "Radio.HoldPosition",  say = "Держать позицию!",    cmd = "держу позицию" },
	cmd_go     = { slot = 9,  snd = "Radio.GoGoGo",        say = "Вперёд, вперёд!",     cmd = "иду вперёд" },
	cmd_back   = { slot = 10, snd = "Radio.TeamFallBack",  say = "Отступаем!",          cmd = "отхожу" },
	cmd_getout = { slot = 22, snd = "Radio.GetOutOfThere", say = "Уходите оттуда!",     cmd = "сваливаю от бомбы" },
	cmd_backup = { slot = 18, snd = "Radio.NeedBackup",    say = "Нужна помощь!",       cmd = "бегу к тебе" },
	cmd_defuse = { slot = 18, snd = "Radio.NeedBackup",    say = "Нужна помощь!",       cmd = "иду дефузить" },
	cmd_clear  = { slot = 19, snd = "Radio.SectorClear",   say = "Сектор чист.",        cmd = "понял, тут чисто" },
	cmd_site   = { slot = 11, snd = "Radio.StickTogether", say = "Держимся вместе!",    cmd = "иду с тобой" },
	cmd_defend = { slot = 4,  snd = "Radio.HoldPosition",  say = "Охраняйте бомбу!",    cmd = "держу позицию" }
}
TB.STICK <- { slot = 11, snd = "Radio.StickTogether", say = "Держимся вместе!" }

TB.UserId <- function(p) {
	local i = p.entindex()
	return (i in TB.uid) ? TB.uid[i] : -1
}
// отдать радио-команду от имени игрока: боты его команды её услышат
TB.Radio <- function(human, c) {
	if (!TB_CFG.obey_enabled) return false
	local ok = false, uid = TB.UserId(human)
	if (uid >= 0) {
		try { ok = SendGlobalGameEvent("player_radio", { userid = uid, slot = c.slot }) } catch (e) { ok = false }
	}
	if (TB_CFG.radio_feedback) {
		try { EmitSoundEx({ sound_name = c.snd, entity = human, channel = 0, volume = 1.0, filter_type = 4 }) } catch (e) {}
		ClientPrint(human, 3, "\x01(Радио) \x07" + ((human.GetTeam() == 2) ? "FF4040" : "99CCFF") + TB.Clean(TB.Name(human)) + "\x01 :  " + c.say)
	}
	if (TB_CFG.debug) printl("[ToxicBots] радио " + c.slot + " userid=" + uid + " -> " + ok)
	return ok
}
TB.BombPlanted <- function() { return Entities.FindByClassname(null, "planted_c4") != null }

TB.ObeyChance <- function(rude, polite) {
	if (rude) return 0.08
	local p = 0.75 + (TB.resp - 50) / 100.0
	if (polite) p += 0.2
	return TB.Clamp(p, 0.15, 0.98)
}

TB.OnCommand <- function(human, a, name, rude, polite) {
	local c = TB.CMDS[name], ht = human.GetTeam()
	local mates = TB.Bots(ht)
	if (ht < 2 || mates.len() == 0) {
		// своих ботов нет — отвечает противник
		local foe = TB.PickBot(a, human, false)
		if (foe == null) return
		local ctx = TB.Ctx(human, foe)
		ctx.site = (TBC.Site(a) != "") ? TBC.Site(a) : "плент"
		TB.BotSay(foe, (ht >= 2 && TBC.Rnd() < 0.5) ? TBC.EventLine("cmd_no_mates", null, ctx) : TBC.Reply(a, "enemy", ctx, !TB.IsToxic(foe, rude, polite))[0], false)
		return
	}
	local bot = TB.FindMentioned(a.toks, mates)
	if (bot == null) {
		local alive = []
		foreach (b in mates) if (TB.Alive(b)) alive.push(b)
		bot = TBC.Pick(alive.len() > 0 ? alive : mates)
	}
	local ctx = TB.Ctx(human, bot)
	ctx.word <- (a.rudeWord != "") ? a.rudeWord : "так"
	local site = TBC.Site(a)
	ctx.site = (site != "") ? site : "плент"
	ctx.cmd = c.cmd + ((site != "" && (name == "cmd_follow" || name == "cmd_site" || name == "cmd_go" || name == "cmd_backup")) ? " на " + site : "")

	// «дефайте/охраняйте бомбу»: Т — сторожить заложенную бомбу, КТ — держать точку
	local okEv = null
	if (name == "cmd_defend") {
		local planted = TB.BombPlanted()
		if (ht == 3 && planted) { name = "cmd_defuse"; c = TB.CMDS.cmd_defuse; ctx.cmd = c.cmd }
		else if (ht == 2 && planted) okEv = "defend_planted"
		else if (ht == 2) { c = TB.CMDS.cmd_cover; okEv = "defend_not_planted" }
		else okEv = "defend_ct"
	}
	local where = (name in TB.CMD_WHERE) ? TB.CMD_WHERE[name] : "идти туда"
	if (site != "" && (name == "cmd_follow" || name == "cmd_site" || name == "cmd_go")) where = (name == "cmd_site") ? "идти на " + site : where + " на " + site
	TB.lastCmd = { t = Time(), obeyed = false, where = where }

	if (name == "cmd_defuse") {
		if (ht == 2) { TB.BotSay(bot, TBC.EventLine("cmd_wrong_team", null, ctx), true); TB.Talked(bot); return }
		if (!TB.BombPlanted()) { TB.BotSay(bot, TBC.EventLine("cmd_no_bomb", null, ctx), true); TB.Talked(bot); return }
	}
	if (name == "cmd_clear" && TB.BombPlanted() && ht == 3) ctx.cmd = "понял, проверю другой плент"

	if (TBC.Rnd() < TB.ObeyChance(rude, polite)) {
		TB.Radio(human, c)
		TB.lastCmd.obeyed = true
		local toxic = TB.IsToxic(bot, rude, polite, a.mat)
		TB.BotSay(bot, (okEv != null) ? TB.Ev(okEv, bot, ctx, null, toxic) : TBC.EventLine(toxic ? "cmd_ok" : "cmd_ok_nice", null, ctx), true)
		if (mates.len() > 1 && TBC.Rnd() < 0.35) {
			local o = TBC.Pick(mates)
			if (o.entindex() != bot.entindex()) TB.BotSay(o, TBC.EventLine("cmd_pile", null, TB.Ctx(human, o)), true, 1.0)
		}
	} else {
		TB.BotSay(bot, TBC.EventLine(rude ? "cmd_refuse_rude" : "cmd_refuse", null, ctx), true)
	}
	TB.Talked(bot)
}

// ------------------------------------------------------------ «давайте быть командой»
TB.OnTeamUp <- function(human, a, rude, polite) {
	local ht = human.GetTeam(), mates = TB.Bots(ht)
	if (ht < 2 || mates.len() == 0) {
		local foe = TB.PickBot(a, human, false)
		if (foe != null) TB.BotSay(foe, TBC.Reply(a, "enemy", TB.Ctx(human, foe), !TB.IsToxic(foe, rude, polite))[0], false)
		return
	}
	local bot = TB.FindMentioned(a.toks, mates)
	if (bot == null) bot = TBC.Pick(mates)
	local ctx = TB.Ctx(human, bot)
	if (!rude && TBC.Rnd() < TB.ObeyChance(false, polite) + 0.15) {
		TB.Respect(10)
		TB.peaceUntil = Time() + TB_CFG.peace_time
		TB.Radio(human, TB.STICK)
		TB.BotSay(bot, TB.Ev("team_up_ok", bot, ctx, null, TB.IsToxic(bot, false, polite)), false)
		if (mates.len() > 1 && TBC.Rnd() < 0.5) {
			local o = TBC.Pick(mates)
			if (o.entindex() != bot.entindex()) TB.BotSay(o, TBC.EventLine("cmd_pile", null, TB.Ctx(human, o)), false, 1.2)
		}
	} else TB.BotSay(bot, TBC.EventLine("team_up_no", null, ctx), false)
	TB.Talked(bot)
	// противник может прокомментировать
	local foes = TB.Bots(ht == 2 ? 3 : 2)
	if (foes.len() > 0 && TBC.Rnd() < 0.3) {
		local f = TBC.Pick(foes)
		TB.BotSay(f, TBC.Reply(a, "enemy", TB.Ctx(human, f), !TB.IsToxic(f))[0], false, 2.0)
	}
}

// ------------------------------------------------------------ подъёб про счёт бота
TB.OnKdTaunt <- function(human, a, rude, polite) {
	local bot = TB.PickBot(a, human, TBC.Rnd() < 0.35)
	if (bot == null) return
	local ctx = TB.Ctx(human, bot)
	local hs = TB.St(human.entindex()), bs = TB.St(bot.entindex())
	local ahead = (bs.k - bs.d > hs.k - hs.d) || (bs.k - bs.d == hs.k - hs.d && bs.k >= hs.k)
	local toxic = TB.IsToxic(bot, rude, polite, a.mat)
	TB.BotSay(bot, TB.Ev(ahead ? "kd_ahead" : "kd_behind", bot, ctx, null, toxic), false)
	TB.Talked(bot)
	if (!ahead) { TB.FunAfterReply(human, bot, a, rude, toxic); return }
	// кто-то из своих впрягается
	if (toxic && TBC.Rnd() < TB_CFG.pile_chance) {
		local same = TB.Bots(bot.GetTeam())
		local o = (same.len() > 1) ? TBC.Pick(same) : null
		if (o != null && o.entindex() != bot.entindex()) TB.BotSay(o, TBC.EventLine("pile", null, TB.Ctx(human, o)), false, 1.5)
	}
}

// ------------------------------------------------------------ «я поддаюсь / ща без поддавок»
TB.OnSandbag <- function(human, a, rude, polite) {
	local hs = TB.St(human.entindex())
	local bad = hs.k <= hs.d
	if (TB.sandbag == null || TB.sandbag.state != "claimed")
		TB.sandbag = { state = "claimed", ck = hs.k, cd = hs.d, rounds = 0 }
	local bot = TB.PickBot(a, human, TBC.Rnd() < 0.4)
	if (bot == null) return
	local ctx = TB.Ctx(human, bot)
	local ev = bad ? "sandbag_claim_bad" : "sandbag_claim_good"
	TB.BotSay(bot, TB.Ev(ev, bot, ctx, null, TB.IsToxic(bot, rude, polite, a.mat)), false)
	TB.Talked(bot)
}

// после раунда: заметить, что ты нормально сыграл (и проверить «поддавки»)
TB.CheckPlay <- function(human, delay) {
	if (human == null || human.GetTeam() < 2) return delay
	local hs = TB.St(human.entindex()), ht = human.GetTeam()
	local mates = TB.Bots(ht), foes = TB.Bots(ht == 2 ? 3 : 2)
	local good = hs.rk >= 2 || hs.rdmg >= 250
	if (good) TB.Respect(hs.rk >= 3 ? 5 : 3)
	local sb = TB.sandbag
	if (sb != null && sb.state == "claimed") {
		sb.rounds++
		if (good) {
			sb.state = "proven"
			TB.Respect(8)
			if (mates.len() > 0) { local b = TBC.Pick(mates); TB.BotSay(b, TBC.EventLine("sandbag_proven", null, TB.Ctx(human, b)), false, delay); delay += 2.0 }
			if (foes.len() > 0) { local f = TBC.Pick(foes); TB.BotSay(f, TBC.EventLine("sandbag_proven_enemy", null, TB.Ctx(human, f)), false, delay); delay += 2.0 }
			return delay
		}
		if (sb.rounds >= 2 && hs.rk == 0) {
			sb.state = "failed"
			local all = TB.Bots()
			if (all.len() > 0) { local b = TBC.Pick(all); TB.BotSay(b, TBC.EventLine("sandbag_failed", null, TB.Ctx(human, b)), false, delay); delay += 2.0 }
			return delay
		}
	}
	if (good && TBC.Rnd() < TB_CFG.good_round_chance) {
		if (mates.len() > 0) { local b = TBC.Pick(mates); TB.BotSay(b, TB.Ev("good_round_team", b, TB.Ctx(human, b)), false, delay); delay += 2.0 }
		if (foes.len() > 0 && TBC.Rnd() < 0.5) { local f = TBC.Pick(foes); TB.BotSay(f, TB.Ev("good_round_enemy", f, TB.Ctx(human, f)), false, delay); delay += 2.0 }
	}
	return delay
}

TB.Command <- function(human, text) {
	local arg = text.len() > 4 ? text.slice(4) : ""
	if (arg == "off") { TB_CFG.enabled = false; ClientPrint(human, 3, "\x04[ToxicBots]\x01 выключен") }
	else if (arg == "on") { TB_CFG.enabled = true; ClientPrint(human, 3, "\x04[ToxicBots]\x01 включён") }
	else if (arg == "stat" || arg == "stats") TB.PrintTable(human)
	else if (arg == "debug") { TB_CFG.debug = !TB_CFG.debug; ClientPrint(human, 3, "\x04[ToxicBots]\x01 debug = " + TB_CFG.debug) }
	else if (arg.len() > 6 && arg.slice(0, 6) == "toxic ") {
		local v = 0.5
		try { v = arg.slice(6).tofloat() } catch (e) {}
		TB_CFG.toxicity = TB.Clamp(v, 0.0, 1.0)
		TB.temper = {}
		ClientPrint(human, 3, "\x04[ToxicBots]\x01 токсичность = " + TB_CFG.toxicity)
	}
	else if (arg == "duel") { if (TB.duel != null) TB.DuelStop(); TB.offer = null; ClientPrint(human, 3, "\x04[ToxicBots]\x01 дуэль отменена, боты снова с оружием") }
	else if (arg == "mood") ClientPrint(human, 3, "\x04[ToxicBots]\x01 уважение ботов к тебе: " + TB.resp.tointeger() + "/100, токсичность: " + TB_CFG.toxicity)
	else ClientPrint(human, 3, "\x04[ToxicBots]\x01 !tb on | off | stat | mood | toxic 0.3 | duel (отменить дуэль) | debug")
}

// ------------------------------------------------------------ голос (voice/ГОЛОС.bat пишет сюда)
TB.voiceInit <- false
TB.PollVoice <- function() {
	local s = FileToString(TB_CFG.voice_file)
	if (s == null || s == "") { TB.voiceInit = true; TB.voiceMiss++; return }
	TB.voiceMiss = 0
	if (s == TB.voiceLast) return
	TB.voiceLast = s
	local lines = [], st = 0
	for (local i = 0; i <= s.len(); i++) {
		if (i == s.len() || s[i] == '\n') { if (i > st) lines.push(s.slice(st, i)); st = i + 1 }
	}
	foreach (ln in lines) {
		local tab = ln.find("\t")
		if (tab == null) continue
		local seq = 0
		try { seq = ln.slice(0, tab).tointeger() } catch (e) { continue }
		if (seq <= TB.voiceSeq) continue
		TB.voiceSeq = seq
		if (!TB.voiceInit) continue
		local text = ln.slice(tab + 1)
		if (text.len() > 0 && text[text.len() - 1] == '\r') text = text.slice(0, text.len() - 1)
		if (text == "") continue
		local host = GetListenServerHost()
		if (host == null) { local hs = TB.Humans(); if (hs.len() > 0) host = hs[0] }
		if (host == null) continue
		if (TB_CFG.voice_echo) ClientPrint(host, 3, "\x07AAAAAA[голос] " + TB.Clean(text))
		TB.OnHumanSay(host, text)
	}
	TB.voiceInit = true
}

// ------------------------------------------------------------ кто уёбищнее всех
TB.Rating <- function(s, round) {
	return round ? (s.rk * 100 + s.rdmg - s.rd * 30) : (s.k * 100 + s.dmg - s.d * 30 - s.tk * 150)
}
// игроки команды, отсортированные от худшего к лучшему
TB.Ranking <- function(team, round) {
	local arr = []
	foreach (p in TB.Players()) if (p.GetTeam() == team) arr.push(p)
	arr.sort(function(a, b) {
		local ra = TB.Rating(TB.St(a.entindex()), round), rb = TB.Rating(TB.St(b.entindex()), round)
		return ra <=> rb
	})
	return arr
}
TB.WorstCtx <- function(ctx, w, round) {
	local s = TB.St(w.entindex())
	ctx.worst <- TB.Name(w)
	ctx.wk <- round ? s.rk : s.k
	ctx.wd <- round ? s.rd : s.d
	ctx.wdmg <- round ? s.rdmg : s.dmg
	return ctx
}
TB.PrintTable <- function(to) {
	foreach (team in [2, 3]) {
		local line = (team == 2) ? "T: " : "CT: "
		foreach (i, p in TB.Ranking(team, false)) {
			local s = TB.St(p.entindex())
			line += (i + 1) + ") " + TB.Clean(TB.Name(p)) + " " + s.k + "/" + s.d + " " + s.dmg + "dmg  "
		}
		ClientPrint(to, 3, "\x04[худшие сверху]\x01 " + line)
	}
}

TB.Human <- function() {
	local h = GetListenServerHost()
	if (h == null) { local hs = TB.Humans(); if (hs.len() > 0) h = hs[0] }
	return h
}

// разбор после раунда / матча
TB.AfterRound <- function(winner) {
	local human = TB.Human()
	local loser = (winner == 2) ? 3 : 2
	local lbots = TB.Bots(loser), wbots = TB.Bots(winner)
	local t2 = TB.TeamScore(2), t3 = TB.TeamScore(3)
	local maxr = Convars.GetInt("mp_maxrounds"), winl = Convars.GetInt("mp_winlimit")
	local over = !TB.matchOver && ((maxr != null && maxr > 0 && t2 + t3 >= maxr) ||
		(winl != null && winl > 0 && (t2 >= winl || t3 >= winl)))
	if (over) { TB.MatchEnd(winner); return }
	local delay = 0.5
	if (lbots.len() > 0 && TBC.Rnd() < TB_CFG.round_talk_chance) {
		local b = TBC.Pick(lbots)
		TB.BotSay(b, TB.Ev("round_lost", b, TB.Ctx(human, b)), true, delay)
		delay += 2.0
	}
	if (wbots.len() > 0 && human != null && human.GetTeam() == loser && TBC.Rnd() < 0.35) {
		local b = TBC.Pick(wbots)
		TB.BotSay(b, TB.Ev("round_won", b, TB.Ctx(human, b)), false, delay)
	}
	delay = TB.CheckPlay(human, delay)
	local rank = TB.Ranking(loser, true)
	if (rank.len() >= 2 && lbots.len() > 0 && TBC.Rnd() < TB_CFG.worst_chance) {
		local worst = rank[0]
		local sp = null
		foreach (b in lbots) if (b.entindex() != worst.entindex()) { sp = b; if (TBC.Rnd() < 0.5) break }
		if (sp == null) return
		local ctx = TB.WorstCtx(TB.Ctx(human, sp), worst, true)
		TB.BotSay(sp, TB.Ev("worst_round", sp, ctx), false, delay + 1.5)
		if (TB.IsBot(worst)) {
			if (TBC.Rnd() < TB_CFG.worst_reply_chance) {
				// огрызается конкретно тому, кто его обосрал
				if (TBC.Rnd() < 0.5) TB.BotSay(worst, TBC.EventLine("worst_snap", null, TB.CtxTo(human, worst, sp)), false, delay + 4.0)
				else TB.BotSay(worst, TB.Ev("worst_reply", worst, TB.Ctx(human, worst)), false, delay + 4.0)
			}
		} else if (TBC.Rnd() < 0.5) {
			local b2 = TBC.Pick(lbots)
			if (b2.entindex() != sp.entindex()) TB.BotSay(b2, TB.Ev("worst_human", b2, TB.WorstCtx(TB.Ctx(worst, b2), worst, true)), false, delay + 4.0)
		}
	}
}

TB.MatchEnd <- function(winner) {
	if (TB.matchOver) return
	TB.matchOver = true
	local human = TB.Human()
	local loser = (winner == 2) ? 3 : 2
	local lbots = TB.Bots(loser), wbots = TB.Bots(winner)
	local rank = TB.Ranking(loser, false)
	local delay = 0.5
	if (lbots.len() > 0) {
		local b = TBC.Pick(lbots)
		local ctx = TB.Ctx(human, b)
		if (rank.len() > 0) TB.WorstCtx(ctx, rank[0], false)
		TB.BotSay(b, TB.Ev("match_lost", b, ctx), false, delay)
		delay += 2.5
		if (rank.len() > 0) {
			local b2 = b
			foreach (x in lbots) if (x.entindex() != rank[0].entindex()) { b2 = x; if (TBC.Rnd() < 0.5) break }
			TB.BotSay(b2, TBC.EventLine("match_worst", null, TB.WorstCtx(TB.Ctx(human, b2), rank[0], false)), false, delay)
			delay += 2.5
			local top = "Топ уёбищ катки: "
			for (local i = 0; i < rank.len() && i < 3; i++) {
				local s = TB.St(rank[i].entindex())
				top += (i + 1) + ") " + TB.Name(rank[i]) + " " + s.k + "/" + s.d + ", " + s.dmg + " урона  "
			}
			TB.BotSay(b2, top, false, delay)
			delay += 2.0
		}
	}
	if (wbots.len() > 0) {
		local b = TBC.Pick(wbots)
		TB.BotSay(b, TB.Ev("match_won", b, TB.Ctx(human, b)), false, delay)
	}
}

// ------------------------------------------------------------ игровые события
if (!("TB_Events" in getroottable())) ::TB_Events <- {}

TB_Events.OnGameEvent_player_say <- function(params) {
	TB.EnsureThink()
	local p = TB.NoteUid(params.userid)
	if (p == null || TB.IsBot(p)) return
	local text = params.text
	if (text.len() >= 3 && text.slice(0, 3) == "!tb") { TB.Command(p, text); return }
	TB.OnHumanSay(p, text)
}

TB_Events.OnGameEvent_player_hurt <- function(params) {
	local v = GetPlayerFromUserID(params.userid), a = GetPlayerFromUserID(params.attacker)
	if (v == null || a == null || a.entindex() == v.entindex() || a.GetTeam() == v.GetTeam()) return
	local s = TB.St(a.entindex())
	local dmg = ("dmg_health" in params) ? params.dmg_health : 0
	if (dmg > 100) dmg = 100
	s.dmg += dmg
	s.rdmg += dmg
}

TB_Events.OnGameEvent_player_death <- function(params) {
	TB.EnsureThink()
	local v = GetPlayerFromUserID(params.userid), a = GetPlayerFromUserID(params.attacker)
	if (v == null) return
	local vs = TB.St(v.entindex())
	vs.d++; vs.rd++
	local first = !TB.roundDeath
	TB.roundDeath = true
	if (!TB_CFG.enabled) return
	local human = TB.Human()
	if (a != null && a.entindex() != v.entindex()) {
		local as = TB.St(a.entindex())
		if (a.GetTeam() == v.GetTeam()) {
			as.tk++
			if (!TB.IsBot(a) && TB.IsBot(v)) { TB.Respect(-12); TB.BotSay(v, TB.Ev("human_tk", v, TB.Ctx(a, v)), false) }
		} else {
			as.k++; as.rk++
			local hs = ("headshot" in params) && params.headshot
			if (hs) as.hs++
			TB.weapon <- ("weapon" in params) ? params.weapon : "ствол"
			if (TB.IsBot(a) && !TB.IsBot(v)) {
				as.killedMe++
				TB.lastBot = a.entindex(); TB.lastBotTime = Time()
				if (!TB.DuelOn() && TBC.Rnd() < TB_CFG.kill_taunt_chance)
					TB.BotSay(a, TB.Ev(hs && TBC.Rnd() < 0.6 ? "kill_human_hs" : "kill_human", a, TB.Ctx(v, a)), false)
			} else if (!TB.IsBot(a) && TB.IsBot(v)) {
				TB.lastBot = v.entindex(); TB.lastBotTime = Time()
				if (!TB.DuelOn() && TBC.Rnd() < TB_CFG.death_whine_chance)
					TB.BotSay(v, TB.Ev("killed_by_human", v, TB.Ctx(a, v)), false)
			}
		}
	}
	try { TB.FunDeath(v, a, params) } catch (e) { printl("[ToxicBots] ошибка: " + e) }
	if (first && !TB.IsBot(v) && TBC.Rnd() < TB_CFG.first_death_chance) {
		local mates = TB.Bots(v.GetTeam())
		if (mates.len() > 0) { local b = TBC.Pick(mates); TB.BotSay(b, TB.Ev("human_first_death", b, TB.Ctx(v, b)), true, 0.8) }
	}
}

TB_Events.OnGameEvent_round_start <- function(params) {
	TB.EnsureThink()
	if (TB.TeamScore(2) + TB.TeamScore(3) == 0) TB.ResetMatch()
	TB.ResetRound()
	TB.resp += (TB_CFG.start_respect - TB.resp) * 0.1   // обиды понемногу забываются
	if (!TB.greeted && TB_CFG.enabled) {
		TB.greeted = true
		local bots = TB.Bots(), h = TB.Human()
		if (bots.len() > 0 && h != null && TBC.Rnd() < TB_CFG.map_start_chance) {
			local b = TBC.Pick(bots)
			TB.BotSay(b, TB.Ev("map_start", b, TB.Ctx(h, b)), false, 2.0)
		}
		TB.FunMapStart(h)
	}
	if (TB_CFG.enabled) try { TB.FunRoundStart() } catch (e) { printl("[ToxicBots] ошибка: " + e) }
}

TB_Events.OnGameEvent_round_end <- function(params) {
	TB.EnsureThink()
	local msg = ("message" in params) ? params.message : ""
	if (msg == "#Game_Commencing") { TB.ResetMatch(); return }
	local w = ("winner" in params) ? params.winner : 0
	if (!TB_CFG.enabled || (w != 2 && w != 3)) return
	TB.Later(0.6, function() { TB.AfterRound(w) })   // счёт команд обновится
	TB.Later(7.0, function() { TB.FunAfterRound(w) })
}

TB_Events.OnGameEvent_cs_win_panel_match <- function(params) {
	if (!TB_CFG.enabled) return
	local t2 = TB.TeamScore(2), t3 = TB.TeamScore(3)
	if (t2 != t3) TB.MatchEnd(t2 > t3 ? 2 : 3)
}

TB_Events.OnGameEvent_player_spawn <- function(params) { TB.EnsureThink(); TB.NoteUid(params.userid) }

IncludeScript("toxicbots/fun_items")
IncludeScript("toxicbots/fun_social")

try { TB.PrecacheClips() } catch (e) { printl("[ToxicBots] клипы: " + e) }
__CollectGameEventCallbacks(TB_Events)
printl("[ToxicBots] загружен: " + TB_DATA.intents.len() + " интентов, " + TB_DATA.classics.len() + " готовых ответов. Пиши в чат, боты ответят. !tb — команды.")
