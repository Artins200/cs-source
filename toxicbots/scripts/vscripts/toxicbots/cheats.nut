// =====================================================================
//  ToxicBots: ЧИТ-ПАНЕЛЬ «ToxicHack» (!c) — только для одиночной игры с ботами.
//  Читы работают через VScript на твоём же локальном сервере; боты замечают
//  их по эффектам (а не по тексту команды) и реагируют как живые люди:
//    стадия 1 «что-то не так» -> 2 обвинения, репорты, голосование за кик
//    -> 3 свои переходят к врагам (огонь по своим выключен) -> 4 перемирие всех ботов:
//    хоровод вокруг читера (никто ни в кого не стреляет, раунд не кончается),
//    потом все вместе атакуют, и так по кругу, пока не выключишь читы.
//  Команды движка, помеченные как читерские (bot_zombie и т.п.), не используются:
//  «мир» делается тем, что все боты оказываются в одной команде.
// =====================================================================
TB.cheat <- { aim = false, wh = false, speed = false, god = false, ammo = false }
TB.CHEAT_ORDER <- ["aim", "wh", "speed", "god", "ammo"]
TB.CHEAT_NAME <- { aim = "Аимбот", wh = "ВХ (радар)", speed = "Спидхак", god = "Бессмертие", ammo = "Бесконечные патроны" }
TB.CHEAT_ARG <- {}
foreach (k, list in { aim = ["1", "aim", "аим", "аимбот"], wh = ["2", "wh", "вх", "радар"], speed = ["3", "speed", "спид", "спидхак"],
	god = ["4", "god", "год", "годмод", "бессмертие"], ammo = ["5", "ammo", "патроны"], killall = ["6", "killall", "kill", "убить"],
	off = ["0", "off", "выкл"] }) foreach (w in list) TB.CHEAT_ARG[w] <- k
TB.STAGE_AT <- [0.0, 20.0, 40.0, 65.0, 90.0]
TB.STAGE_NAME <- ["всё спокойно", "что-то не так", "обвиняют в читах", "свои против тебя", "все против тебя"]
TB.CHEAT_FILE <- "toxicbots_cheat.txt"

TB.CheatReset <- function() {
	if ("cheatOrig" in TB) TB.RestoreTeams()
	if (("cheatIgnore" in TB) && TB.cheatIgnore) TB.SetIgnore(false)
	TB.sus <- 0.0            // подозрение ботов 0..100
	TB.susStage <- 0         // 0..4
	TB.cheatSeen <- {}       // какие читы боты уже «спалили» (по одной реплике на чит)
	TB.cheatOrig <- {}       // entindex -> { team, name }: исходная команда перебежавших ботов
	TB.cheatMode <- null     // null | "defect" | "dance" | "attack"
	TB.cheatModeT <- 0.0
	TB.cheatNext <- 0.0      // когда можно следующую «читерскую» реплику
	TB.cheatChantT <- 0.0
	TB.cheatAccuseT <- 0.0
	TB.cheatVoteT <- -100.0
	TB.cheatKillAll <- 0     // сколько раз нажимали «убить всех»
	TB.cheatKillAllT <- -100.0
	TB.cheatPending <- false // «убить всех» -> стадия 4 начнётся со следующего раунда
	TB.cheatGodHits <- 0
	TB.cheatIgnore <- false
	TB.stageT <- -100.0      // когда поднялась стадия (следующая — не раньше чем через cheat_stage_min)
	TB.cheatLastT <- Time()
	TB.radarNext <- 0.0
}
TB.cheatApi <- {}            // функции движка, которые не сработали (больше не дёргаем)
TB.clipMax <- {}
TB.CheatReset()

// после вылета/смены карты посреди хоровода — вернуть нормальные правила раунда
try {
	local s = FileToString(TB.CHEAT_FILE)
	if (s != null && s.find("ignore") != null) { TB.SrvCmd("mp_ignore_round_win_conditions 0"); StringToFile(TB.CHEAT_FILE, "") }
} catch (e) {}

// ------------------------------------------------------------ мелочи
TB.CheatAny <- function() { foreach (k, v in TB.cheat) if (v) return true; return false }
TB.OtherTeam <- function(t) { return (t == 2) ? 3 : 2 }
TB.TeamTag <- function(t) { return (t == 3) ? "CT" : "T" }
TB.ApiFail <- function(key, e) {
	if (key in TB.cheatApi) return
	TB.cheatApi[key] <- true
	printl("[ToxicBots] чит-панель: " + key + " не поддерживается этой версией игры (" + e + ")")
}
TB.GetHp <- function(p) {
	if (!("hp" in TB.cheatApi)) try { return p.GetHealth() } catch (e) { TB.ApiFail("hp", e) }
	return NetProps.GetPropInt(p, "m_iHealth")
}
TB.SetHp <- function(p, v) {
	if (!("hp" in TB.cheatApi)) try { p.SetHealth(v); return } catch (e) { TB.ApiFail("hp", e) }
	NetProps.SetPropInt(p, "m_iHealth", v)
}
TB.EyePos <- function(p) {
	if (!("eyepos" in TB.cheatApi)) try { return p.EyePosition() } catch (e) { TB.ApiFail("eyepos", e) }
	return p.GetOrigin() + Vector(0, 0, 62)
}
TB.EyeYaw <- function(p) {
	if (!("eyeang" in TB.cheatApi)) try { return p.EyeAngles().y } catch (e) { TB.ApiFail("eyeang", e) }
	try { return p.GetAngles().y } catch (e) {}
	return 0.0
}
TB.Snap <- function(p, pitch, yaw) {
	if ("snap" in TB.cheatApi) return
	try { p.SnapEyeAngles(QAngle(pitch, yaw, 0)) } catch (e) { TB.ApiFail("snap", e) }
}
TB.GetVel <- function(p) {
	if (!("absvel" in TB.cheatApi)) try { return p.GetAbsVelocity() } catch (e) { TB.ApiFail("absvel", e) }
	try { return p.GetVelocity() } catch (e) {}
	return Vector(0, 0, 0)
}
TB.SetVel <- function(p, v) {
	if (!("absvel" in TB.cheatApi)) try { p.SetAbsVelocity(v); return } catch (e) { TB.ApiFail("absvel", e) }
	try { p.SetVelocity(v) } catch (e) { TB.ApiFail("vel", e) }
}
TB.Norm180 <- function(a) {
	for (local i = 0; a > 180.0 && i < 8; i++) a -= 360.0
	for (local i = 0; a < -180.0 && i < 8; i++) a += 360.0
	return a
}
// убить бота «от имени» attacker (для своих — сам себя: огонь по своим выключен)
TB.KillBot <- function(v, a) {
	if (!TB.Alive(v)) return true
	if (!("takedmg" in TB.cheatApi)) try { v.TakeDamage(10000.0, 2, a); return true } catch (e) { TB.ApiFail("takedmg", e) }
	return false
}
TB.CtxCheat <- function(human, bot) {
	local c = TB.Ctx(human, bot)
	c.team_other <- TB.TeamTag(TB.OtherTeam(human != null ? human.GetTeam() : 2))
	return c
}
// within — крайний срок: «ХОРОВОД!» после конца хоровода уже не говорят
TB.CheatLine <- function(bot, ev, extra = 0.0, ctx = null, within = null) {
	if (bot == null) return false
	if (ctx == null) ctx = TB.CtxCheat(TB.Human(), bot)
	local old = TB.tag
	TB.tag = "cheat"
	local r = TB.BotSay(bot, TBC.EventLine(ev, null, ctx), false, extra, false, null, within)
	TB.tag = old
	if (r) TB.cheatNext = Time() + 3.0
	return r
}
TB.AnyBot <- function(team = 0, alive = false) {
	local out = []
	foreach (b in TB.Bots(team)) if (!alive || TB.Alive(b)) out.push(b)
	return out.len() > 0 ? TBC.Pick(out) : null
}

// ------------------------------------------------------------ команды: тихо меняем команду бота
// (m_iTeamNum, без ChangeTeam — тот убил бы бота). ИИ бота сразу видит новых врагов.
TB.SetTeamQuiet <- function(b, t) {
	local i = b.entindex()
	if (b.GetTeam() == t) return
	if (!(i in TB.cheatOrig)) TB.cheatOrig[i] <- { team = b.GetTeam(), name = TB.Name(b) }
	NetProps.SetPropInt(b, "m_iTeamNum", t)
}
TB.RestoreTeams <- function() {
	foreach (i, o in TB.cheatOrig) {
		local p = PlayerInstanceFromIndex(i)
		if (p != null && p.IsValid() && TB.IsBot(p) && TB.Name(p) == o.name && p.GetTeam() != o.team) NetProps.SetPropInt(p, "m_iTeamNum", o.team)
	}
	TB.cheatOrig = {}
}
// раунд не кончается, пока все боты в одной команде (иначе игра решит, что «нужны игроки», и перезапустит матч)
TB.SetIgnore <- function(on) {
	if (TB.cheatIgnore == on) return true
	if (!TB.SrvCmd("mp_ignore_round_win_conditions " + (on ? 1 : 0))) return false
	TB.cheatIgnore = on
	try { StringToFile(TB.CHEAT_FILE, on ? "ignore" : "") } catch (e) {}
	return true
}

// ------------------------------------------------------------ подозрение и стадии
TB.SusAdd <- function(d, why = null, speaker = null) {
	if (!TB_CFG.cheats_enabled) return
	TB.sus = TB.Clamp(TB.sus + d, 0.0, 100.0)
	// впервые заметили конкретный чит — об этом скажут прямо
	if (why != null && !(why in TB.cheatSeen) && TB.sus >= 12.0) {
		TB.cheatSeen[why] <- true
		local h = TB.Human()
		if (speaker == null && h != null) speaker = TB.AnyBot(TB.OtherTeam(h.GetTeam()))
		if (speaker == null) speaker = TB.AnyBot()
		TB.CheatLine(speaker, "cheat_" + why, 0.5)
	}
	TB.CheatStage()
}
TB.StageOf <- function(s) {
	for (local i = 4; i >= 1; i--) if (s >= TB.STAGE_AT[i]) return i
	return 0
}
TB.CheatStage <- function() {
	local st = TB.StageOf(TB.sus)
	if (st <= TB.susStage) return
	// по одной стадии и с паузой: люди сначала удивляются, потом злятся, потом объединяются
	if (Time() - TB.stageT < TB_CFG.cheat_stage_min) return
	TB.susStage++
	TB.stageT = Time()
	TB.CheatEnter(TB.susStage)
}
TB.CheatEnter <- function(st) {
	local h = TB.Human()
	if (h == null) return
	local ht = h.GetTeam(), foes = TB.Bots(TB.OtherTeam(ht)), mates = TB.Bots(ht)
	if (st == 1) {
		TB.CheatLine(TB.AnyBot(TB.OtherTeam(ht)), "cheat_sus", 0.5)
	} else if (st == 2) {
		local a = TB.AnyBot()
		TB.CheatLine(a, "cheat_accuse", 0.5)
		local b = TB.OtherBotOf(a)
		if (b != null) TB.CheatLine(b, "cheat_accuse", 1.0)
		TB.cheatAccuseT = Time()
		TB.CheatVote(h, 6.0)
	} else if (st == 3) {
		if (mates.len() == 0) { TB.CheatLine(TB.AnyBot(), "cheat_accuse", 0.5); return }
		// свои пытаются стрелять, но огонь по своим выключен -> переходят к врагам
		local delay = 0.5, last = Time()
		foreach (i, m in mates) if (i < 2 && TB.CheatLine(m, "cheat_ff", delay)) { delay += 2.5; last = TB.lastSayT }
		TB.cheatMode = "defect"; TB.cheatModeT = Time()
		// переходят, когда жалобы уже прозвучали в чате
		TB.Later(TB.Max(delay + 4.0, last - Time() + 3.0), function() { TB.CheatDefect() })
	} else if (st == 4) {
		TB.CheatLine(TB.AnyBot(), "cheat_unite", 0.5)
		TB.Later(1.5, function() { TB.CheatAttack(true) })        // перемирие: все боты по одну сторону
		TB.Later(5.0, function() { if (TB.susStage >= 4) TB.CheatDance() })
	}
}
TB.OtherBotOf <- function(b) {
	local out = []
	foreach (x in TB.Bots()) if (b == null || x.entindex() != b.entindex()) out.push(x)
	return out.len() > 0 ? TBC.Pick(out) : null
}
// свои переходят к врагам
TB.CheatDefect <- function() {
	local h = TB.Human()
	if (h == null || TB.susStage < 3) return
	local ht = h.GetTeam(), ot = TB.OtherTeam(ht), mates = TB.Bots(ht)
	if (mates.len() == 0) return
	foreach (m in mates) TB.SetTeamQuiet(m, ot)
	TB.CheatLine(mates[0], "cheat_defect", 0.3)
	local foes = []
	foreach (b in TB.Bots(ot)) if (!(b.entindex() in TB.cheatOrig)) foes.push(b)
	if (foes.len() > 0) TB.CheatLine(TBC.Pick(foes), "cheat_welcome", 1.5)
}
// атака: все боты против тебя (в противоположной команде)
TB.CheatAttack <- function(quiet = false) {
	local h = TB.Human()
	if (h == null) return
	local was = TB.cheatMode
	TB.cheatMode = "attack"; TB.cheatModeT = Time()
	local ot = TB.OtherTeam(h.GetTeam())
	foreach (b in TB.Bots()) TB.SetTeamQuiet(b, ot)
	if (TB.cheatIgnore) TB.Later(0.6, function() { if (TB.cheatMode != "dance") TB.SetIgnore(false) })
	if (!quiet && was == "dance") TB.CheatLine(TB.AnyBot(0, true), "cheat_attack", 0.2, null, Time() + 8.0)
}
// хоровод: все боты в твоей команде (никто ни в кого не стреляет), прыгают кругом вокруг тебя
TB.CheatDance <- function() {
	local h = TB.Human()
	if (h == null || !TB.Alive(h) || TB.AnyBot(0, true) == null) return   // танцевать некому
	if (Time() - TB.cheatKillAllT < 30.0) return   // после «убить всех» — ждём следующего раунда
	// без серверных команд раунд закончится/перезапустится — тогда просто атака
	if (!TB.SetIgnore(true)) { TB.CheatAttack(); return }
	TB.cheatMode = "dance"; TB.cheatModeT = Time(); TB.cheatChantT = Time() + 5.0
	local ht = h.GetTeam()
	TB.Later(0.4, function() { if (TB.cheatMode == "dance") foreach (b in TB.Bots()) TB.SetTeamQuiet(b, ht) })
	TB.CheatLine(TB.AnyBot(0, true), "cheat_dance", 0.3, null, TB.cheatModeT + 8.0)
}
TB.DanceTick <- function(now) {
	local h = TB.Human()
	if (h == null || !TB.Alive(h)) return
	local c = h.GetOrigin(), bots = []
	foreach (b in TB.Bots()) if (TB.Alive(b)) bots.push(b)
	local n = bots.len()
	if (n == 0) return
	local r = 150.0 + 20.0 * n, spin = (now - TB.cheatModeT) * 1.2
	foreach (i, b in bots) {
		local ang = spin + 6.2832 * i / n
		local p = b.GetOrigin()
		local vx = (c.x + cos(ang) * r - p.x) * 4.0, vy = (c.y + sin(ang) * r - p.y) * 4.0
		local l = sqrt(vx * vx + vy * vy)
		if (l > 320.0) { vx = vx * 320.0 / l; vy = vy * 320.0 / l }
		local ground = (NetProps.GetPropInt(b, "m_fFlags") & 1) != 0
		local vz = ground ? 270.0 : TB.GetVel(b).z   // на земле — прыжок, в воздухе — не мешаем падать
		TB.SetVel(b, Vector(vx, vy, vz))
		TB.Snap(b, 0.0, atan2(c.y - p.y, c.x - p.x) * 57.2958)   // все смотрят на читера
	}
	if (now >= TB.cheatChantT) {
		TB.cheatChantT = now + RandomFloat(5.0, 8.0)
		TB.CheatLine(TB.AnyBot(0, true), "cheat_chant", 0.0, null, TB.cheatModeT + TB_CFG.cheat_dance_time - 1.0)
	}
}
// всё выключил и подозрение спало — мир
TB.CheatCalm <- function() {
	local was = TB.cheatMode
	TB.cheatMode = null
	TB.RestoreTeams()
	if (TB.cheatIgnore) TB.Later(0.6, function() { if (TB.cheatMode != "dance") TB.SetIgnore(false) })
	if (was != null) TB.CheatLine(TB.AnyBot(), "cheat_calm", 0.5)
}

// ------------------------------------------------------------ голосование за кик (как в игре; хоста кикнуть нельзя)
TB.SysPrint <- function(text, delay) {
	TB.Later(delay, function() { foreach (h in TB.Humans()) ClientPrint(h, 3, "\x04[Голосование]\x01 " + text) })
}
TB.CheatVote <- function(h, delay) {
	if (Time() - TB.cheatVoteT < 60.0) return
	local bots = TB.Bots()
	if (bots.len() == 0) return
	TB.cheatVoteT = Time()
	local caller = TBC.Pick(bots), name = TB.Clean(TB.Name(h))
	TB.CheatLine(caller, "cheat_kick_call", delay)
	local t = TB.Max(delay + 2.0, TB.lastSayT - Time() + 1.5)
	TB.SysPrint(TB.Clean(TB.Name(caller)) + " предлагает кикнуть игрока «" + name + "». Причина: читы. F1 — да, F2 — нет", t)
	TB.SysPrint("Да: " + bots.len() + "   Нет: 0", t + 3.0)
	TB.SysPrint("Голосование не прошло: игрока «" + name + "» нельзя кикнуть — он хост сервера.", t + 6.0)
	local other = TB.OtherBotOf(caller)
	TB.Later(t + 6.5, function() { if (other != null && other.IsValid()) TB.CheatLine(other, "cheat_kick_fail", 0.5) })
}

// ------------------------------------------------------------ «УБИТЬ ВСЕХ НА КАРТЕ»
// флуд не ждёт общей очереди чата: все пишут почти одновременно, капсом, мёртвые — с *УБИТ*
TB.FloodAt <- function(b, text, delay, voice = false) {
	local idx = b.entindex(), who = TB.Name(b), at = Time() + delay
	TB.chat.push({ t = at, len = 6, bot = idx, tag = "cheat" })
	if (!(idx in TB.botNext) || TB.botNext[idx] < at + 0.3) TB.botNext[idx] <- at + 0.3
	TB.Push({ t = at, tag = "cheat", f = function() {
		local p = PlayerInstanceFromIndex(idx)
		if (p != null && p.IsValid() && TB.IsBot(p) && TB.Name(p) == who) {
			local seen = TB.Print(p, text, false)
			if (seen && voice) TB.Tts(p, text)
		}
	} })
}
TB.CheatFlood <- function(h, allies) {
	TB.CancelTag("chatter")
	local bots = TB.Bots()
	if (bots.len() == 0) return 0.0
	local used = {}, t = 0.5, total = 6 + 3 * bots.len()
	if (total > 28) total = 28
	local allySaid = {}
	for (local i = 0; i < total; i++) {
		local b = TBC.Pick(bots), ev = "cheat_killall"
		if (i < 2 && TB.cheatKillAll > 1) ev = "cheat_killall_again"
		else if ((b.entindex() in allies) && !(b.entindex() in allySaid)) { ev = "cheat_killall_ally"; allySaid[b.entindex()] <- true }
		local text = null
		for (local k = 0; k < 5; k++) { text = TBC.EventLine(ev, null, TB.CtxCheat(h, b)); if (text != null && !(text in used)) break }
		if (text == null) continue
		used[text] <- true
		if (TBC.Rnd() < 0.25) text += "!!!"
		TB.FloodAt(b, text, t, i % 3 == 0)
		t += RandomFloat(0.25, 0.9)
	}
	return t
}
TB.CheatKillAll <- function(h) {
	local ht = h.GetTeam(), victims = [], allies = {}
	foreach (b in TB.Bots()) if (TB.Alive(b)) { victims.push(b); if (b.GetTeam() == ht) allies[b.entindex()] <- true }
	if (victims.len() == 0) { ClientPrint(h, 3, "\x07FF3030[ToxicHack]\x01 все и так мертвы"); return }
	TB.cheatKillAll++
	TB.cheatKillAllT = Time()
	// мёртвым незачем танцевать; правила раунда обратно — пусть раунд закончится
	if (TB.cheatMode == "dance") TB.cheatMode = "attack"
	TB.SetIgnore(false)
	foreach (b in victims) TB.KillBot(b, (b.GetTeam() == ht) ? b : h)
	// TakeDamage недоступен — встроенная команда (не читерская)
	TB.Later(0.3, function() { foreach (b in TB.Bots()) if (TB.Alive(b)) { TB.SrvCmd("bot_kill all"); break } })
	local wasStage = TB.susStage
	TB.sus = 100.0
	if (wasStage < 4) { TB.susStage = 4; TB.cheatPending = true }   // перемирие и хоровод — со следующего раунда
	local t = TB.CheatFlood(h, allies)
	TB.CheatVote(h, t + 0.5)
	// второй раз — кто-то ливает с сервера (бот-квота пришлёт новенького)
	if (TB.cheatKillAll >= 2 && TB_CFG.kick_enabled) {
		local qs = []
		foreach (b in TB.Bots()) if (!TB.IsTroll(b)) qs.push(b)
		local q = (qs.len() > 0) ? TBC.Pick(qs) : null
		if (q != null) {
			local idx = q.entindex(), name = TB.Name(q), uid = TB.UserId(q)
			TB.Later(t + 1.0, function() {
				local p = PlayerInstanceFromIndex(idx)
				if (p == null || !p.IsValid() || TB.Name(p) != name) return
				TB.FloodAt(p, TBC.EventLine("cheat_ragequit", null, TB.CtxCheat(h, p)), 0.1, true)
				TB.Later(2.5, function() { if (uid >= 0) TB.SrvCmd("kickid " + uid + " Ragequit"); else TB.SrvCmd("kick \"" + name + "\"") })
			})
		}
	}
}

// ------------------------------------------------------------ панель
TB.Meter <- function() {
	local n = (TB.sus / 10.0).tointeger(), s = ""
	for (local i = 0; i < 10; i++) s += (i < n) ? "|" : "."
	return "[" + s + "] " + TB.sus.tointeger() + "%  (" + TB.STAGE_NAME[TB.susStage] + ")"
}
TB.CheatPanel <- function(h) {
	ClientPrint(h, 3, "\x07FF3030===== ToxicHack v6.6 =====\x01  (боты видят только последствия)")
	foreach (i, k in TB.CHEAT_ORDER)
		ClientPrint(h, 3, "\x07FFD040!c " + (i + 1) + "\x01  " + TB.CHEAT_NAME[k] + "  " + (TB.cheat[k] ? "\x0740FF40[ВКЛ]" : "\x07888888[выкл]"))
	ClientPrint(h, 3, "\x07FFD040!c 6\x01  \x07FF3030УБИТЬ ВСЕХ НА КАРТЕ\x01     \x07FFD040!c 0\x01  выключить всё")
	ClientPrint(h, 3, "\x01Подозрение ботов: " + TB.Meter())
}
TB.IsCheatCmd <- function(text) {
	return text == "!c" || text.find("!c ") == 0 || text.find("!cheat") == 0 || text.find("!чит") == 0
}
TB.CheatCmd <- function(h, text) {
	if (!TB_CFG.cheats_enabled) { ClientPrint(h, 3, "\x07FF3030[ToxicHack]\x01 выключено в config.nut (cheats_enabled)"); return }
	local sp = text.find(" "), arg = (sp != null) ? text.slice(sp + 1) : ""
	while (arg.len() > 0 && arg[0] == ' ') arg = arg.slice(1)
	if (arg == "") { TB.CheatPanel(h); return }
	if (!(arg in TB.CHEAT_ARG)) { TB.CheatPanel(h); return }
	local k = TB.CHEAT_ARG[arg]
	if (k == "killall") { TB.CheatKillAll(h); return }
	if (k == "off") {
		foreach (c in TB.CHEAT_ORDER) if (TB.cheat[c]) TB.CheatToggle(h, c, false)
		ClientPrint(h, 3, "\x07FF3030[ToxicHack]\x01 всё выключено. Подозрение: " + TB.Meter())
		return
	}
	TB.CheatToggle(h, k, !TB.cheat[k])
	ClientPrint(h, 3, "\x07FF3030[ToxicHack]\x01 " + TB.CHEAT_NAME[k] + ": " + (TB.cheat[k] ? "\x0740FF40ВКЛ" : "\x07888888выкл") + "\x01   подозрение: " + TB.Meter())
}
TB.CheatToggle <- function(h, k, on) {
	TB.cheat[k] = on
	if (on) { TB.EnsureThink(); TB.cheatLastT = Time(); if (TB.thinker != null) { AddThinkToEnt(TB.thinker, "TB_Think"); TB.thinkAt = Time() + 0.1 } }
	if (!on && k == "speed") try { NetProps.SetPropFloat(h, "m_flLaggedMovementValue", 1.0) } catch (e) {}
	if (!on && k == "god") { local hp = TB.GetHp(h); if (hp > 100) TB.SetHp(h, 100) }
}

// ------------------------------------------------------------ сами читы (каждый тик)
TB.AimTick <- function(h) {
	if (!("buttons" in TB.cheatApi)) {
		local btn = 0
		try { btn = NetProps.GetPropInt(h, "m_nButtons") } catch (e) { TB.ApiFail("buttons", e); return }
		if ((btn & 1) == 0) return   // наводим только когда стреляешь
	}
	local eye = TB.EyePos(h), yaw = TB.EyeYaw(h), ht = h.GetTeam(), best = null, bestA = 25.0
	foreach (b in TB.Bots()) {
		if (b.GetTeam() == ht || !TB.Alive(b)) continue
		local hd = TB.EyePos(b) - Vector(0, 0, 2)
		local d = hd - eye, a = TB.Norm180(atan2(d.y, d.x) * 57.2958 - yaw)
		if (a < 0) a = -a
		if (a >= bestA) continue
		// сквозь стены не наводим (если трассировка есть)
		local clear = true
		if (!("trace" in TB.cheatApi)) try { clear = TraceLine(eye, hd - d * (24.0 / d.Length()), h) >= 0.99 } catch (e) { TB.ApiFail("trace", e) }
		if (clear) { best = d; bestA = a }
	}
	if (best == null) return
	local flat = sqrt(best.x * best.x + best.y * best.y)
	TB.Snap(h, -atan2(best.z, flat) * 57.2958, atan2(best.y, best.x) * 57.2958)
}
TB.RadarTick <- function(h) {
	local ht = h.GetTeam(), yaw = TB.EyeYaw(h), hp = h.GetOrigin(), list = []
	foreach (b in TB.Bots()) {
		if (b.GetTeam() == ht || !TB.Alive(b)) continue
		local p = b.GetOrigin(), dx = p.x - hp.x, dy = p.y - hp.y
		local rel = TB.Norm180(atan2(dy, dx) * 57.2958 - yaw)
		local arr = (rel > -45.0 && rel < 45.0) ? "^" : ((rel >= 45.0 && rel <= 135.0) ? "<" : ((rel <= -45.0 && rel >= -135.0) ? ">" : "v"))
		local dz = p.z - hp.z
		list.push({ d = sqrt(dx * dx + dy * dy), s = arr + " " + TB.Clean(TB.Name(b)) + " " + (sqrt(dx * dx + dy * dy) / 52.5).tointeger() + "м" + (dz > 90.0 ? " выше" : (dz < -90.0 ? " ниже" : "")) })
	}
	if (list.len() == 0) return
	list.sort(function(a, b) { return a.d <=> b.d })
	local s = "ВХ:"
	foreach (i, x in list) if (i < 4) s += "   " + x.s
	ClientPrint(h, 4, s)   // 4 = по центру экрана
}
TB.AmmoTick <- function(h) {
	if (!("weapon" in TB.cheatApi)) try {
		local w = h.GetActiveWeapon()
		if (w == null) return
		local m = w.GetMaxClip1()
		if (m > 0 && w.Clip1() < m) w.SetClip1(m)
		return
	} catch (e) { TB.ApiFail("weapon", e) }
	// запасной путь — через свойства
	local w = NetProps.GetPropEntity(h, "m_hActiveWeapon")
	if (w == null) return
	local cls = w.GetClassname(), c = NetProps.GetPropInt(w, "m_iClip1")
	if (c < 0) return
	if (!(cls in TB.clipMax) || c > TB.clipMax[cls]) TB.clipMax[cls] <- c
	if (c < TB.clipMax[cls]) NetProps.SetPropInt(w, "m_iClip1", TB.clipMax[cls])
}

// -> через сколько секунд снова (null — делать нечего)
TB.CheatTick <- function(now) {
	if (!TB_CFG.cheats_enabled) return null
	local dt = TB.Clamp(now - TB.cheatLastT, 0.0, 2.0)
	TB.cheatLastT = now
	local h = TB.Human(), any = TB.CheatAny(), alive = h != null && TB.Alive(h)
	if (alive) {
		if (TB.cheat.speed) { try { NetProps.SetPropFloat(h, "m_flLaggedMovementValue", TB_CFG.cheat_speed) } catch (e) {} TB.SusAdd(1.0 * dt, "speed") }
		if (TB.cheat.god && TB.GetHp(h) < TB_CFG.cheat_god_hp) TB.SetHp(h, TB_CFG.cheat_god_hp)
		if (TB.cheat.ammo) { try { TB.AmmoTick(h) } catch (e) {} TB.SusAdd(0.25 * dt) }
		if (TB.cheat.aim) { try { TB.AimTick(h) } catch (e) {} }
		if (TB.cheat.wh) {
			TB.SusAdd(0.35 * dt)   // префайры из-за углов
			if (now >= TB.radarNext) { TB.radarNext = now + 0.5; try { TB.RadarTick(h) } catch (e) {} }
		}
	}
	// читы выключены — подозрение медленно спадает
	if (!any && TB.sus > 0.0) {
		TB.sus = TB.Clamp(TB.sus - TB_CFG.cheat_decay * dt, 0.0, 100.0)
		local st = TB.StageOf(TB.sus)
		if (TB.susStage >= 3 && TB.sus < 45.0) { TB.susStage = st; TB.cheatPending = false; TB.CheatCalm() }
		else if (st < TB.susStage && TB.susStage < 3) TB.susStage = st
	}
	// стадия 2+: время от времени напоминают, кто ты
	if (any && TB.susStage >= 2 && now - TB.cheatAccuseT > 25.0 && now > TB.cheatNext && TB.cheatMode != "dance") {
		TB.cheatAccuseT = now
		TB.CheatLine(TB.AnyBot(), "cheat_accuse")
		if (h != null) TB.CheatVote(h, 4.0)
	}
	// хоровод 20 с -> атака 30 с -> хоровод...
	if (TB.cheatMode == "dance") {
		if (now - TB.cheatModeT > TB_CFG.cheat_dance_time) TB.CheatAttack()
		else TB.DanceTick(now)
	} else if (TB.cheatMode == "attack" && TB.susStage >= 4 && any && now - TB.cheatModeT > TB_CFG.cheat_attack_time) {
		TB.cheatModeT = now   // не вышло (все мертвы / только что «убить всех») — попробуем позже
		TB.CheatDance()
	}
	if (TB.cheatMode == "dance" || (alive && TB.cheat.aim)) return 0.1
	if (alive && (TB.cheat.speed || TB.cheat.god || TB.cheat.ammo || TB.cheat.wh)) return 0.25
	if (TB.sus > 0.0 || TB.cheatMode != null) return 1.0
	return null
}

// ------------------------------------------------------------ события
// урон: бессмертие (считаем «съеденные» попадания), аимбот (одно попадание = смерть)
TB.CheatHurt <- function(params) {
	if (!TB_CFG.cheats_enabled) return
	local v = GetPlayerFromUserID(params.userid), a = GetPlayerFromUserID(params.attacker)
	if (v == null || a == null || a.entindex() == v.entindex()) return
	if (!TB.IsBot(v) && TB.IsBot(a) && TB.cheat.god) {
		TB.SetHp(v, TB_CFG.cheat_god_hp)
		TB.cheatGodHits++
		TB.SusAdd(4.0, (TB.cheatGodHits >= 3) ? "god" : null, a)
	}
	if (!TB.IsBot(a) && TB.IsBot(v) && TB.cheat.aim && TB.Alive(v) && a.GetTeam() != v.GetTeam()) TB.KillBot(v, a)
}
// смерть: -> true, если обычные реакции (нытьё, подколы) не нужны
TB.CheatDeath <- function(v, a, params) {
	if (!TB_CFG.cheats_enabled) return false
	local now = Time()
	if (now - TB.cheatKillAllT < 3.0) return true   // флуд уже всё сказал
	if (a == null || a.entindex() == v.entindex()) return false
	if (!TB.IsBot(a) && TB.IsBot(v)) {
		if (!TB.CheatAny() && TB.susStage < 1) return false
		local why = TB.cheat.aim ? "aim" : (TB.cheat.wh ? "wh" : (TB.cheat.ammo ? "ammo" : null))
		TB.SusAdd(TB.cheat.aim ? 10.0 : (TB.cheat.wh ? 4.0 : (TB.CheatAny() ? 2.0 : 0.0)), why, v)
		if (TB.susStage >= 1 && now > TB.cheatNext && TBC.Rnd() < 0.5) TB.CheatLine(v, (TB.susStage == 1) ? "cheat_sus" : "cheat_killed", 0.3)
		return TB.susStage >= 1
	}
	if (TB.IsBot(a) && !TB.IsBot(v) && TB.susStage >= 2) {
		if (TBC.Rnd() < 0.7) TB.CheatLine(a, "cheat_human_died", 0.3)
		return true
	}
	return false
}
// ты пишешь в чат, когда тебя уже подозревают
TB.CheatOnSay <- function(human, a, text) {
	if (!TB_CFG.cheats_enabled || TB.susStage < 2) return false
	local words = TB.Words(a), deny = false
	for (local i = 0; i < words.len(); i++) {
		if (words[i] == "скилл" || words[i] == "скил" || words[i] == "честно") deny = true
		if (words[i] == "не" && i + 1 < words.len() && TB.Pre(words[i + 1], "чит")) deny = true
		if (words[i] == "без" && i + 1 < words.len() && TB.Pre(words[i + 1], "чит")) deny = true
	}
	if (!deny && TBC.Rnd() > 0.45) return false
	local b = TB.PickBot(a, human, false)
	if (b == null) return false
	TB.BotSay(b, TBC.EventLine(deny ? "cheat_deny" : "cheat_reply", null, TB.CtxCheat(human, b)), false)
	TB.Talked(b)
	return true
}
// обычные разборы раунда («кто худший», «кикнем Vasya») посреди этого цирка неуместны
TB.CheatQuiet <- function() { return TB_CFG.cheats_enabled && (Time() - TB.cheatKillAllT < 40.0 || TB.susStage >= 3 || TB.cheatMode != null) }
TB.CheatRoundStart <- function() {
	if (!TB_CFG.cheats_enabled) return
	local ft = 0
	try { ft = Convars.GetInt("mp_freezetime") } catch (e) {}
	if (ft == null) ft = 0
	if (TB.cheatPending) {
		TB.cheatPending = false
		TB.Later(ft + 1.0, function() { TB.CheatEnter(4) })
	} else if (TB.susStage >= 4 && TB.CheatAny()) {
		TB.Later(ft + 1.5, function() { if (TB.susStage >= 4) TB.CheatDance() })
	}
}
// новенький бот (бот-квота заменила ливнувшего) посреди цирка
TB.CheatNewBot <- function(p) {
	if (!TB_CFG.cheats_enabled || (TB.susStage < 2 && TB.cheatKillAll == 0)) return
	local idx = p.entindex(), name = TB.Name(p)
	TB.Later(4.0, function() {
		local q = PlayerInstanceFromIndex(idx)
		if (q == null || !q.IsValid() || TB.Name(q) != name) return
		local h = TB.Human()
		if (h != null && TB.cheatMode == "attack") TB.SetTeamQuiet(q, TB.OtherTeam(h.GetTeam()))
		else if (h != null && TB.cheatMode == "dance") TB.SetTeamQuiet(q, h.GetTeam())
		TB.CheatLine(q, "cheat_newcomer")
	})
}
