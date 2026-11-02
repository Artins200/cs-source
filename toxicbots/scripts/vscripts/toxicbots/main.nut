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
TB.ResetMatch <- function() { TB.stats = {}; TB.matchOver = false }

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
	return ctx
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

TB.Later <- function(delay, fn) { TB.queue.push({ t = Time() + delay, f = fn }) }

// бот "печатает" (задержка по длине) и отправляет
TB.BotSay <- function(bot, text, teamOnly, extra = 0.0) {
	if (bot == null || text == null || text == "") return
	local snd = ""
	if (text[0] == 2) {
		local e = text.find("\x02", 1)
		if (e != null) { snd = text.slice(1, e); text = text.slice(e + 1) }
	}
	local idx = bot.entindex(), now = Time()
	local typing = 0.6 + (text.len() / 2.0) / TB_CFG.typing_speed
	if (typing > 4.5) typing = 4.5
	local t = now + extra + typing + RandomFloat(0.0, 0.6)
	if ((idx in TB.botNext) && TB.botNext[idx] > t) t = TB.botNext[idx] + 0.8
	TB.botNext[idx] <- t + 0.5
	TB.queue.push({ t = t, f = function() {
		local b = PlayerInstanceFromIndex(idx)
		if (b != null && b.IsValid() && TB.IsBot(b)) {
			local seen = TB.Print(b, text, teamOnly)
			if (seen && snd != "") TB.PlayClip(b, snd)
			else if (seen) TB.Tts(b, text)
		}
	} })
	if (TB_CFG.debug) printl("[ToxicBots] " + TB.Name(bot) + (teamOnly ? " (team)" : "") + ": " + text)
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
		TB.nextVoice = now + 0.25
		try { TB.PollVoice() } catch (e) { printl("[ToxicBots] голос: " + e) }
	}
	return 0.1
}

TB.EnsureThink <- function() {
	if (TB.thinker != null && TB.thinker.IsValid()) return
	local e = SpawnEntityFromTable("info_target", { targetname = "toxicbots_think" })
	if (e == null) return
	e.ValidateScriptScope()
	e.GetScriptScope().TB_Think <- function() { return ::TB.Tick() }
	AddThinkToEnt(e, "TB_Think")
	TB.thinker = e
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

TB.OnHumanSay <- function(human, text) {
	if (!TB_CFG.enabled || TBC.Rnd() > TB_CFG.reply_chance) return
	local ht = human.GetTeam()
	local all = TB.Bots()
	if (all.len() == 0) return
	local a = TBC.Analyze(text)
	local mates = [], foes = []
	foreach (b in all) { if (b.GetTeam() == ht) mates.push(b); else foes.push(b) }

	local bot = TB.FindMentioned(a.toks, all)
	if (bot == null && TB.lastBot != null && Time() - TB.lastBotTime < 20.0 && TBC.Rnd() < 0.5) {
		local lb = PlayerInstanceFromIndex(TB.lastBot)
		if (lb != null && lb.IsValid() && TB.IsBot(lb)) bot = lb
	}
	if (bot == null) {
		local wantTeam = (a.intent != null && (a.intent.name in TB.TEAM_INTENTS)) ? TBC.Rnd() < 0.85 : TBC.Rnd() > TB_CFG.enemy_share
		local pool = wantTeam ? mates : foes
		if (pool.len() == 0) pool = wantTeam ? foes : mates
		if (pool.len() == 0) return
		bot = TBC.Pick(pool)
	}
	local side = (bot.GetTeam() == ht) ? "team" : "enemy"
	local r = TBC.Reply(a, side, TB.Ctx(human, bot))
	if (TB_CFG.debug) printl("[ToxicBots] \"" + text + "\" -> " + r[1] + " (" + a.score + ") слово=" + a.word)
	TB.BotSay(bot, r[0], false)
	TB.lastBot = bot.entindex()
	TB.lastBotTime = Time()

	// второй бот подтявкивает
	if (all.len() > 1 && TBC.Rnd() < TB_CFG.pile_chance) {
		local other = bot
		for (local n = 0; n < 5 && other.entindex() == bot.entindex(); n++) other = TBC.Pick(all)
		if (other.entindex() != bot.entindex()) TB.BotSay(other, TBC.EventLine("pile", null, TB.Ctx(human, other)), false, 1.5)
	}
}

TB.Command <- function(human, text) {
	local arg = text.len() > 4 ? text.slice(4) : ""
	if (arg == "off") { TB_CFG.enabled = false; ClientPrint(human, 3, "\x04[ToxicBots]\x01 выключен") }
	else if (arg == "on") { TB_CFG.enabled = true; ClientPrint(human, 3, "\x04[ToxicBots]\x01 включён") }
	else if (arg == "stat" || arg == "stats") TB.PrintTable(human)
	else if (arg == "debug") { TB_CFG.debug = !TB_CFG.debug; ClientPrint(human, 3, "\x04[ToxicBots]\x01 debug = " + TB_CFG.debug) }
	else ClientPrint(human, 3, "\x04[ToxicBots]\x01 !tb on | !tb off | !tb stat | !tb debug")
}

// ------------------------------------------------------------ голос (voice/ГОЛОС.bat пишет сюда)
TB.voiceInit <- false
TB.PollVoice <- function() {
	local s = FileToString(TB_CFG.voice_file)
	if (s == null || s == "") { TB.voiceInit = true; return }
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
		TB.BotSay(b, TBC.EventLine("round_lost", null, TB.Ctx(human, b)), true, delay)
		delay += 2.0
	}
	if (wbots.len() > 0 && human != null && human.GetTeam() == loser && TBC.Rnd() < 0.35) {
		local b = TBC.Pick(wbots)
		TB.BotSay(b, TBC.EventLine("round_won", null, TB.Ctx(human, b)), false, delay)
	}
	local rank = TB.Ranking(loser, true)
	if (rank.len() >= 2 && lbots.len() > 0 && TBC.Rnd() < TB_CFG.worst_chance) {
		local worst = rank[0]
		local sp = null
		foreach (b in lbots) if (b.entindex() != worst.entindex()) { sp = b; if (TBC.Rnd() < 0.5) break }
		if (sp == null) return
		local ctx = TB.WorstCtx(TB.Ctx(human, sp), worst, true)
		TB.BotSay(sp, TBC.EventLine("worst_round", null, ctx), false, delay + 1.5)
		if (TB.IsBot(worst)) {
			if (TBC.Rnd() < TB_CFG.worst_reply_chance)
				TB.BotSay(worst, TBC.EventLine("worst_reply", null, TB.Ctx(human, worst)), false, delay + 4.0)
		} else if (TBC.Rnd() < 0.5) {
			local b2 = TBC.Pick(lbots)
			if (b2.entindex() != sp.entindex()) TB.BotSay(b2, TBC.EventLine("worst_human", null, TB.WorstCtx(TB.Ctx(worst, b2), worst, true)), false, delay + 4.0)
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
		TB.BotSay(b, TBC.EventLine("match_lost", null, ctx), false, delay)
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
		TB.BotSay(b, TBC.EventLine("match_won", null, TB.Ctx(human, b)), false, delay)
	}
}

// ------------------------------------------------------------ игровые события
if (!("TB_Events" in getroottable())) ::TB_Events <- {}

TB_Events.OnGameEvent_player_say <- function(params) {
	TB.EnsureThink()
	local p = GetPlayerFromUserID(params.userid)
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
			if (!TB.IsBot(a) && TB.IsBot(v)) TB.BotSay(v, TBC.EventLine("human_tk", null, TB.Ctx(a, v)), false)
		} else {
			as.k++; as.rk++
			local hs = ("headshot" in params) && params.headshot
			if (hs) as.hs++
			TB.weapon <- ("weapon" in params) ? params.weapon : "ствол"
			if (TB.IsBot(a) && !TB.IsBot(v)) {
				as.killedMe++
				TB.lastBot = a.entindex(); TB.lastBotTime = Time()
				if (TBC.Rnd() < TB_CFG.kill_taunt_chance)
					TB.BotSay(a, TBC.EventLine(hs && TBC.Rnd() < 0.6 ? "kill_human_hs" : "kill_human", null, TB.Ctx(v, a)), false)
			} else if (!TB.IsBot(a) && TB.IsBot(v)) {
				TB.lastBot = v.entindex(); TB.lastBotTime = Time()
				if (TBC.Rnd() < TB_CFG.death_whine_chance)
					TB.BotSay(v, TBC.EventLine("killed_by_human", null, TB.Ctx(a, v)), false)
			}
		}
	}
	if (first && !TB.IsBot(v) && TBC.Rnd() < TB_CFG.first_death_chance) {
		local mates = TB.Bots(v.GetTeam())
		if (mates.len() > 0) { local b = TBC.Pick(mates); TB.BotSay(b, TBC.EventLine("human_first_death", null, TB.Ctx(v, b)), true, 0.8) }
	}
}

TB_Events.OnGameEvent_round_start <- function(params) {
	TB.EnsureThink()
	if (TB.TeamScore(2) + TB.TeamScore(3) == 0) TB.ResetMatch()
	TB.ResetRound()
	if (!TB.greeted && TB_CFG.enabled) {
		TB.greeted = true
		local bots = TB.Bots(), h = TB.Human()
		if (bots.len() > 0 && h != null && TBC.Rnd() < TB_CFG.map_start_chance) {
			local b = TBC.Pick(bots)
			TB.BotSay(b, TBC.EventLine("map_start", null, TB.Ctx(h, b)), false, 2.0)
		}
	}
}

TB_Events.OnGameEvent_round_end <- function(params) {
	TB.EnsureThink()
	local msg = ("message" in params) ? params.message : ""
	if (msg == "#Game_Commencing") { TB.ResetMatch(); return }
	local w = ("winner" in params) ? params.winner : 0
	if (!TB_CFG.enabled || (w != 2 && w != 3)) return
	TB.Later(0.6, function() { TB.AfterRound(w) })   // счёт команд обновится
}

TB_Events.OnGameEvent_cs_win_panel_match <- function(params) {
	if (!TB_CFG.enabled) return
	local t2 = TB.TeamScore(2), t3 = TB.TeamScore(3)
	if (t2 != t3) TB.MatchEnd(t2 > t3 ? 2 : 3)
}

TB_Events.OnGameEvent_player_spawn <- function(params) { TB.EnsureThink() }

try { TB.PrecacheClips() } catch (e) { printl("[ToxicBots] клипы: " + e) }
__CollectGameEventCallbacks(TB_Events)
printl("[ToxicBots] загружен: " + TB_DATA.intents.len() + " интентов, " + TB_DATA.classics.len() + " готовых ответов. Пиши в чат, боты ответят. !tb — команды.")
