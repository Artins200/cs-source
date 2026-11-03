// =====================================================================
//  ToxicBots — «живость»: боты срутся между собой, бот-тролль, обвинения
//  в читах, кики, «ты сам нас туда позвал», смена команды, опечатки.
// =====================================================================

TB.lastCmd <- null       // { t, obeyed, where } — последний приказ тиммейтам
TB.trollIdx <- -1        // entindex бота-тролля
TB.banterNext <- 0.0
TB.accuseNext <- 0.0
TB.hsRow <- 0            // твоих хедшотов подряд
TB.lastVictim <- -1      // кого ты убил последним
TB.victimRow <- 0
TB.worstRow <- {}        // entindex -> сколько раундов подряд худший в команде
TB.kickVote <- null      // { idx, name, until } — боты предложили кик бота
TB.kickNextRound <- 0
TB.botKillNext <- 0.0
TB.kickHumanT <- -100.0  // когда боты предлагали кикнуть тебя

// где ты «звал» ботов — для «ты сам сказал идти за тобой»
TB.CMD_WHERE <- { cmd_follow = "идти за тобой", cmd_cover = "прикрывать тебя", cmd_hold = "держать позицию",
	cmd_go = "идти вперёд", cmd_back = "отходить", cmd_getout = "валить от бомбы", cmd_backup = "бежать к тебе",
	cmd_defuse = "дефузить", cmd_clear = "чистить плент", cmd_site = "идти на плент", cmd_defend = "охранять бомбу" }

// ------------------------------------------------------------ тролль
TB.Troll <- function() {
	if (!TB_CFG.troll_enabled) return null
	if (TB.trollIdx > 0) {
		local p = PlayerInstanceFromIndex(TB.trollIdx)
		if (p != null && p.IsValid() && TB.IsBot(p)) return p
	}
	local bots = TB.Bots()
	if (bots.len() < 3) return null
	local t = TBC.Pick(bots)
	TB.trollIdx = t.entindex()
	TB.temper[TB.trollIdx] <- 0.25   // тролль не злой, ему просто весело
	return t
}
TB.IsTroll <- function(b) { return b != null && TB_CFG.troll_enabled && b.entindex() == TB.trollIdx }
TB.OtherBot <- function(not1, not2 = null, pool = null) {
	local cand = []
	foreach (b in (pool != null ? pool : TB.Bots())) {
		local i = b.entindex()
		if ((not1 != null && i == not1.entindex()) || (not2 != null && i == not2.entindex())) continue
		cand.push(b)
	}
	return cand.len() > 0 ? TBC.Pick(cand) : null
}
TB.KdOf <- function(p) { local s = TB.St(p.entindex()); return s.k + "-" + s.d }
// ctx от лица бота `bot`, обращающегося к боту `to`
TB.CtxTo <- function(human, bot, to) {
	local ctx = TB.Ctx(human, bot)
	ctx.target = TB.Name(to)
	ctx.tkd <- TB.KdOf(to)
	return ctx
}

// ------------------------------------------------------------ боты срутся между собой
TB.Banter <- function(human, bot, delay) {
	if (Time() < TB.banterNext || TBC.Rnd() > TB_CFG.banter_chance) return
	local x = TB.OtherBot(bot)
	if (x == null) return
	TB.banterNext = Time() + 25.0
	// цепочка: если начало не влезло в чат (очередь) — продолжение не говорим
	// каждая следующая реплика — не позже чем через 8 с после предыдущей, иначе это уже не ответ
	if (!TB.SayChat(x, TBC.EventLine("bot_jab", null, TB.CtxTo(human, x, bot)), false, delay + 1.5, Time() + delay + 12.0)) return
	if (!TB.SayChat(bot, TBC.EventLine("bot_snap", null, TB.CtxTo(human, bot, x)), false, delay + 3.5, TB.lastSayT + 8.0)) return
	local t2 = TB.lastSayT
	if (TBC.Rnd() < 0.55) TB.SayChat(x, TBC.EventLine("bot_snap2", null, TB.CtxTo(human, x, bot)), false, delay + 5.5, t2 + 8.0)
	local tr = TB.Troll()
	if (tr != null && !TB.IsTroll(x) && !TB.IsTroll(bot) && TBC.Rnd() < 0.5)
		TB.SayChat(tr, TBC.EventLine("troll_banter", null, TB.CtxTo(human, tr, TBC.Rnd() < 0.5 ? x : bot)), false, delay + 6.5, t2 + 10.0)
}

// ------------------------------------------------------------ перехват сообщения игрока (до обычного ответа)
TB.INSULTISH <- { insult = 1, noob = 1, weak = 1, blame_team = 1, go_away = 1, deaf_blind = 1 }
// чем «мы» оказались в твоём сообщении — для «ты сам позвал, а теперь мы {word}?»
TB.WE_ARE <- { weak = "слабаки", noob = "нубы", blame_team = "раки", deaf_blind = "слепые", go_away = "лишние", insult = "дебилы" }
TB.FunSay <- function(human, a, text, rude, polite, name) {
	local now = Time(), words = TB.Words(a)
	if (rude) { local m = TB.FindMentioned(a.toks, TB.Bots()); if (m != null) TB.NoteRude(human, m, a) }
	// 0) разговор про дуэль: перенос, отмена, правила, «не купил», «случайно»
	if (TB.DuelTalk(human, a, words, name, rude, polite, text)) return true
	// 1) ответ «да/нет» на предложение дуэли или кика («го кикнем» — это не «да» на дуэль)
	local yn = (name in TB.CMDS || name == "kick" || name == "drop" || name == "duel") ? 0 : TB.YesNo(a, text)
	if (TB.offer != null) {
		if (now > TB.offer.until) TB.offer = null
		else if (yn != 0 && now >= TB.offer.from) {
			local o = TB.offer, b = PlayerInstanceFromIndex(o.bot)
			TB.offer = null
			if (b != null && b.IsValid()) {
				if (yn > 0) TB.StartDuel(o.spec, b, human, "duel_offer_accepted", "duel_accept_next")
				else { local c = TB.Ctx(human, b); c.duel <- o.spec.disp; TB.BotSay(b, TB.DEv("duel_offer_declined", b, c, o.spec, true), false); TB.Respect(-2) }
				return true
			}
		}
	}
	if (TB.kickVote != null) {
		if (now > TB.kickVote.until) TB.kickVote = null
		else if ((yn > 0 || name == "kick") && now >= TB.kickVote.from) {
			local kv = TB.kickVote
			TB.kickVote = null
			local t = PlayerInstanceFromIndex(kv.idx)
			if (t != null && t.IsValid() && TB.IsBot(t)) { TB.DoKick(human, t, null); return true }
		}
	}
	// 2) извинение перед ботом, которого ты обосрал
	if ((name == "sorry" || TB.IsExcuse(words)) && TB.OnSorry(human, a, polite)) return true
	// 3) спецтемы
	if (name == "where_are") {
		local b = TB.FindMentioned(a.toks, TB.Bots())
		if (b != null && !TB.Alive(b)) { TB.DSay(b, "where_dead", TB.Ctx(human, b)); return true }
	}
	if (name == "cmd_defend") { TB.OnCommand(human, a, "cmd_defend", rude, polite); return true }
	if (name == "drop" || (name != "duel" && TB.WantsDrop(a))) { TB.OnDrop(human, a, rude, polite); return true }
	if (name == "duel") { TB.OnDuel(human, a, rude, polite); return true }   // (обычно уже обработано в DuelTalk)
	if (name == "kick") { TB.OnKick(human, a, rude, polite); return true }
	// 3) «ты сам позвал, а теперь мы нубы?»
	local lc = TB.lastCmd
	local named = TB.FindMentioned(a.toks, TB.Bots())
	local toFoe = named != null && named.GetTeam() != human.GetTeam()   // «colin у тебя позор» — это не про тиммейтов
	if (lc != null && !toFoe && now - lc.t < 60.0 && (rude || (name in TB.INSULTISH)) && TBC.Rnd() < 0.75) {
		TB.lastCmd = null
		local mates = TB.Bots(human.GetTeam())
		if (mates.len() > 0) {
			local b = TB.FindMentioned(a.toks, mates)
			if (b == null) b = TBC.Pick(mates)
			local ctx = TB.Ctx(human, b)
			ctx.word <- (a.rudeWord != "") ? a.rudeWord : ((name in TB.WE_ARE) ? TB.WE_ARE[name] : "нубы")
			ctx.cmdwhere <- lc.where
			local said = TB.BotSay(b, TBC.EventLine(lc.obeyed ? "after_cmd_insult" : "after_refuse_insult", null, ctx), false)
			TB.Talked(b)
			if (said && mates.len() > 1 && TBC.Rnd() < 0.4) {
				local o = TB.OtherBot(b, null, mates)
				if (o != null) TB.SayChat(o, TBC.EventLine("pile", null, TB.Ctx(human, o)), false, 1.5, TB.lastSayT + 7.0)
			}
			return true
		}
	}
	// 4) тролля обозвали — ему смешно
	if (rude) {
		local tr = TB.Troll()
		if (tr != null && TB.FindMentioned(a.toks, [tr]) != null && TBC.Rnd() < 0.75) {
			local ctx = TB.Ctx(human, tr)
			ctx.word <- a.rudeWord
			TB.BotSay(tr, TBC.EventLine("troll_insulted", null, ctx), false)
			TB.Talked(tr)
			return true
		}
	}
	return false
}

// «скинь мп5», «дай скаут» — глагол + любое оружие
TB.DROPV <- ["скин", "кинь", "киньт", "дай", "дайт", "дроп", "брос", "отдай", "подел", "подкин", "закин"]
TB.WantsDrop <- function(a) {
	local verb = false
	foreach (w in TB.Words(a)) foreach (v in TB.DROPV) if (TB.Pre(w, v)) verb = true
	if (!verb) return false
	local p = TB.ParseWeapon(a)
	return p != null && ("w" in p) && p.w.cat != "knife"
}

// после обычного ответа бота: тролль угорает, боты срутся, припоминают дуэль
TB.FunAfterReply <- function(human, bot, a, rude, toxic) {
	local tr = TB.Troll()
	local roast = rude || (a.intent != null && (a.intent.name in TB.INSULTISH || a.intent.name == "kd_taunt"))
	if (roast && tr != null && !TB.IsTroll(bot) && TBC.Rnd() < TB_CFG.troll_chance) {
		TB.SayChat(tr, TBC.EventLine("troll_egg", null, TB.CtxTo(human, tr, bot)), false, 2.5, TB.lastSayT + 8.0)
		return
	}
	if (TB.dirty > 0 && toxic && TBC.Rnd() < 0.25) {
		local o = TB.OtherBot(bot)
		if (o != null) { TB.SayChat(o, TBC.EventLine("duel_recall", null, TB.DuelCtx(TB.DuelRecallCtx(human, o))), false, 2.0, TB.lastSayT + 8.0); return }
	}
	TB.Banter(human, bot, 0.5)
}
TB.DuelRecallCtx <- function(human, b) {
	local ctx = TB.Ctx(human, b)
	ctx.duel <- TB.dirtyDisp
	return ctx
}

// ------------------------------------------------------------ кики
TB.PRON <- {}
foreach (w in ["его", "него", "этого", "этот", "он", "её", "ее", "неё", "нее", "эту", "ту", "того"]) TB.PRON[w] <- 1
TB.KickTarget <- function(a, human) {
	local t = TB.FindMentioned(a.toks, TB.Bots())
	if (t != null) return t
	if (TB.kickVote != null) { local p = PlayerInstanceFromIndex(TB.kickVote.idx); if (p != null && p.IsValid()) return p }
	// «кикните его» — того, с кем сейчас говорили (только если есть «его/этого»)
	local pron = false
	foreach (w in TB.Words(a)) if (w in TB.PRON) pron = true
	if (pron && TB.lastBot != null && Time() - TB.lastBotTime < 25.0) {
		local p = PlayerInstanceFromIndex(TB.lastBot)
		if (p != null && p.IsValid() && TB.IsBot(p)) return p
	}
	return null
}
TB.OnKick <- function(human, a, rude, polite) {
	local t = TB.KickTarget(a, human)
	if (t == null) {
		// «го кого-то кикнем?» — ник не назван: переспрашивают
		local me = false
		foreach (w in TB.Words(a)) if (w == "меня" || w == "себя") me = true
		// только что сами предлагали кикнуть тебя — «кого?» звучит тупо, отвечают «тебя»
		if (Time() - TB.kickHumanT < 45.0) me = true
		local b = TB.PickBot(a, human, true)
		if (b != null) { TB.BotSay(b, TBC.EventLine((me || (rude && TBC.Rnd() < 0.5)) ? "kick_self" : "kick_who", null, TB.Ctx(human, b)), false); TB.Talked(b) }
		return
	}
	local rank = TB.Ranking(t.GetTeam(), false)
	local worst = rank.len() > 0 && rank[0].entindex() == t.entindex()
	local p = 0.45 + (TB.resp - 50) / 100.0 + (worst ? 0.3 : 0.0) - (rude ? 0.15 : 0.0)
	if (TBC.Rnd() < TB.Clamp(p, 0.1, 0.9)) TB.DoKick(human, t, null)
	else {
		local b = TB.OtherBot(t)
		if (b == null) return
		TB.BotSay(b, TBC.EventLine("kick_ask_no", null, TB.CtxTo(human, b, t)), false)
		TB.Talked(b)
	}
}
// проголосовали — пробуем реально кикнуть бота
TB.DoKick <- function(human, t, voter) {
	local b = (voter != null) ? voter : TB.OtherBot(t)
	if (b != null) TB.BotSay(b, TBC.EventLine("kick_ask_yes", null, TB.CtxTo(human, b, t)), false)
	local blame = TB.OtherBot(t, b)
	TB.BotSay(t, TBC.EventLine("kick_protest", null, TB.CtxTo(human, t, (blame != null) ? blame : t)), false, 1.5)
	if (!TB_CFG.kick_enabled) return
	local idx = t.entindex(), name = TB.Name(t), uid = TB.UserId(t)
	TB.Later(4.5, function() {
		local p = PlayerInstanceFromIndex(idx)
		if (p == null || !p.IsValid() || TB.Name(p) != name) return
		local ok = (uid >= 0) ? TB.SrvCmd("kickid " + uid + " ToxicBots") : TB.SrvCmd("kick \"" + name + "\"")
		TB.Later(1.5, function() {
			local q = PlayerInstanceFromIndex(idx)
			local gone = q == null || !q.IsValid() || TB.Name(q) != name
			local sp = TB.OtherBot(gone ? null : q)
			if (sp == null) return
			local ctx = TB.Ctx(TB.Human(), sp)
			ctx.target = name
			TB.BotSay(sp, TBC.EventLine(gone ? "kick_done" : "kick_blocked", null, ctx), false)
		})
	})
}

// ------------------------------------------------------------ смерти: дуэли, читы, боты убивают ботов
TB.FunDeath <- function(v, a, params) {
	if (a == null || a.entindex() == v.entindex() || a.GetTeam() == v.GetTeam()) return
	local human = TB.Human()
	local wid = ("weapon" in params) ? params.weapon : ""
	local hs = ("headshot" in params) && params.headshot
	local aBot = TB.IsBot(a), vBot = TB.IsBot(v)
	// --- дуэль
	if (TB.DuelOn()) {
		if (!aBot && vBot) {
			if (!(wid in TB.duel.ids) && wid != "" && TB.WeakerKill(wid, TB.duel)) {
				// с глока в дуэли на диглах — не крысятство
				if (TBC.Rnd() < 0.6) { local c = TB.DuelCtx(TB.Ctx(a, v)); c.dirtyw = (wid in TB.WBYID) ? TB.WBYID[wid].ins : "с пистолета"; TB.BotSay(v, TBC.EventLine("duel_weaker", null, c), false) }
				return
			}
			if (!(wid in TB.duel.ids) && wid != "") {
				TB.dirty++
				TB.dirtyRound = TB.roundNo
				TB.dirtyW = (wid in TB.WBYID) ? TB.WBYID[wid].ins : "со стволом"
				TB.dirtyDisp = TB.duel.disp
				TB.dirtyT = Time(); TB.dirtyBot = v.entindex()
				TB.Respect(-15)
				local ctx = TB.DuelCtx(TB.Ctx(a, v))
				// упрёк — сразу (до твоего «сорри»), поддакивания — с меткой: простят — отменим
				TB.prio = true; TB.tag = "dirty"
				local said = TB.BotSay(v, TBC.EventLine("duel_dirty", null, ctx), false)
				TB.prio = false
				local o = said ? TB.OtherBot(v) : null
				if (o != null && TB.BotSay(o, TBC.EventLine("duel_dirty_pile", null, TB.DuelCtx(TB.Ctx(a, o))), false, 1.8)) {
					local o2 = TB.OtherBot(v, o)
					if (o2 != null && TBC.Rnd() < 0.5) TB.BotSay(o2, TBC.EventLine("duel_dirty_pile", null, TB.DuelCtx(TB.Ctx(a, o2))), false, 3.5)
				}
				TB.tag = null
				return
			}
			if (TBC.Rnd() < 0.4) { TB.BotSay(v, TB.DEv("duel_win", v, TB.DuelCtx(TB.Ctx(a, v))), false); return }
		} else if (aBot && !vBot && ("foe" in TB.duel) && ("free" in TB.duel) && a.entindex() != TB.duel.foe) {
			// один на один, а влез другой бот
			local f = PlayerInstanceFromIndex(TB.duel.foe)
			if (f != null && f.IsValid() && TB.IsBot(f)) { TB.BotSay(f, TBC.EventLine("duel_interfere", null, TB.CtxTo(v, f, a)), false); return }
		} else if (aBot && !vBot && TBC.Rnd() < 0.55) {
			TB.BotSay(a, TB.DEv("duel_kill", a, TB.DuelCtx(TB.Ctx(v, a)), null, true), false)
			return
		}
	}
	// --- бот убил бота
	if (aBot && vBot) {
		if (Time() < TB.botKillNext) return
		local r = TBC.Rnd()
		if (r < TB_CFG.bot_kill_bot_chance) { TB.botKillNext = Time() + 10.0; TB.SayChat(a, TBC.EventLine("bot_kill_bot", null, TB.CtxTo(human, a, v)), false, 0.0, Time() + 10.0) }
		else if (r < TB_CFG.bot_kill_bot_chance * 1.8) { TB.botKillNext = Time() + 10.0; TB.SayChat(v, TBC.EventLine("bot_killed_by_bot", null, TB.CtxTo(human, v, a)), false, 0.0, Time() + 10.0) }
		return
	}
	if (aBot || !vBot) { if (!aBot) return; TB.hsRow = 0; return }   // тебя убили — серия сброшена
	// --- ты убил бота: подозрения в читах
	TB.hsRow = hs ? TB.hsRow + 1 : 0
	if (TB.lastVictim == v.entindex()) TB.victimRow++; else { TB.lastVictim = v.entindex(); TB.victimRow = 1 }
	local s = TB.St(a.entindex())
	if (Time() < TB.accuseNext || !TB_CFG.accuse_enabled) {
		if (TB.dirty > 0 && TB.roundNo - TB.dirtyRound <= 3 && TBC.Rnd() < 0.12) TB.SayChat(v, TBC.EventLine("duel_recall", null, TB.DuelCtx(TB.DuelRecallCtx(a, v))), false, 1.0, Time() + 10.0)
		return
	}
	local ev = null
	if (s.rk >= 5) ev = "accuse_ace"
	else if (TB.hsRow >= 3 && TBC.Rnd() < 0.7) ev = "accuse_hs"
	else if (s.rk == 3 && TBC.Rnd() < 0.5) ev = "accuse_streak"
	else if (TB.victimRow >= 2 && TBC.Rnd() < 0.35) ev = "accuse_victim"
	if (ev == null) return
	TB.accuseNext = Time() + 25.0
	if (ev == "accuse_hs") TB.hsRow = 0
	local foes = TB.Bots(v.GetTeam())
	local sp = (ev == "accuse_victim" || foes.len() == 0) ? v : TBC.Pick(foes)
	local ctx = TB.Ctx(a, sp)
	if (!TB.BotSay(sp, TBC.EventLine(ev, null, ctx), false, 0.6)) return
	TB.Talked(sp)
	TB.AccuseReply(a, 2.5)
}
// тиммейт игрока защищает или подливает
TB.AccuseReply <- function(human, delay) {
	local mates = TB.Bots(human.GetTeam())
	if (mates.len() == 0 || TBC.Rnd() > 0.45) return
	local m = TBC.Pick(mates)
	TB.SayChat(m, TBC.EventLine((TB.resp >= 45 || TBC.Rnd() < 0.3) ? "accuse_defend" : "accuse_join", null, TB.Ctx(human, m)), false, delay, TB.lastSayT + 8.0)
}

// ------------------------------------------------------------ раунды
TB.FunRoundStart <- function() {
	TB.DuelRecover()
	// страховка: дуэли нет, а квоты всё ещё дуэльные — вернуть
	if (!TB.DuelOn() && TB.cvOrig != null) TB.DuelRestoreCv()
	TB.roundNo++
	TB.roundStartT = Time()
	TB.dropPending = null
	TB.lastVictim = -1; TB.victimRow = 0
	local h = TB.Human()
	TB.Later(0.5, function() { TB.SnapMoney() })
	if (TB.duel != null) {
		if (TB.duel.active && TB.duel.round < TB.roundNo) {
			TB.DuelStop()
			TB.offerNextRound = TB.roundNo + 3   // сразу после дуэли новую не предлагают
			local bots = TB.Bots()
			if (bots.len() > 0 && h != null) { local b = TBC.Pick(bots); TB.BotSay(b, TBC.EventLine("duel_end", null, TB.Ctx(h, b)), false, 1.5) }
		} else if (!TB.duel.active) {
			TB.DuelActivate()
			local bots = TB.Bots(h != null && h.GetTeam() == 2 ? 3 : 2)
			if (bots.len() == 0) bots = TB.Bots()
			if (bots.len() > 0 && h != null) { local b = TBC.Pick(bots); TB.BotSay(b, TB.DEv("duel_start", b, TB.DuelCtx(TB.Ctx(h, b)), null, true), false, 1.0) }
			return
		}
	}
	TB.MaybeOffer()
}
TB.FunMapStart <- function(h) {
	local tr = TB.Troll()
	if (tr != null && h != null && TBC.Rnd() < 0.5) TB.BotSay(tr, TBC.EventLine("troll_intro", null, TB.Ctx(h, tr)), false, 6.0)
}

TB.FunAfterRound <- function(winner) {
	if (TB.CheatQuiet()) return
	local human = TB.Human()
	if (human == null || human.GetTeam() < 2) return
	local ht = human.GetTeam(), hs = TB.St(human.entindex())
	local delay = 0.5
	// серии «худший в команде»
	foreach (team in [2, 3]) {
		local rank = TB.Ranking(team, true)
		if (rank.len() < 2) continue
		foreach (i, p in rank) {
			local idx = p.entindex()
			TB.worstRow[idx] <- (i == 0) ? (((idx in TB.worstRow) ? TB.worstRow[idx] : 0) + 1) : 0
		}
	}
	// ноль урона за раунд
	if (hs.rd > 0 && hs.rdmg == 0 && TBC.Rnd() < TB_CFG.aim_bad_chance) {
		local mates = TB.Bots(ht)
		if (mates.len() > 0) { local b = TBC.Pick(mates); TB.BotSay(b, TB.Ev("aim_bad", b, TB.Ctx(human, b)), false, delay); delay += 2.0 }
	}
	// ты затащил раунд — проигравшие орут «читер»
	if (winner == ht && hs.rk >= 2 && TB_CFG.accuse_enabled && TBC.Rnd() < 0.3) {
		local rank = TB.Ranking(ht, true)
		local foes = TB.Bots(ht == 2 ? 3 : 2)
		if (rank.len() > 0 && rank[rank.len() - 1].entindex() == human.entindex() && foes.len() > 0) {
			local f = TBC.Pick(foes)
			if (TB.BotSay(f, TBC.EventLine("accuse_round", null, TB.Ctx(human, f)), false, delay)) {
				delay += 2.0
				TB.AccuseReply(human, delay)
			}
		}
	}
	// предложение кика
	if (TB_CFG.kick_talk && TB.roundNo >= TB.kickNextRound) {
		local cand = null
		foreach (b in TB.Bots()) if ((b.entindex() in TB.worstRow) && TB.worstRow[b.entindex()] >= 3) cand = b
		local hw = (human.entindex() in TB.worstRow) ? TB.worstRow[human.entindex()] : 0
		if (cand != null && TBC.Rnd() < 0.6) {
			local mates = TB.Bots(cand.GetTeam())
			local sp = TB.OtherBot(cand, null, mates)
			if (sp == null) sp = TB.OtherBot(cand)
			if (sp != null) {
				TB.kickNextRound = TB.roundNo + 3
				TB.worstRow[cand.entindex()] <- 0
				// предложение не влезло в чат — без него «против» и «за» звучат из ниоткуда
				if (!TB.BotSay(sp, TBC.EventLine("kick_propose", null, TB.CtxTo(human, sp, cand)), false, delay + 1.0)) return
				local shown = TB.botNext[sp.entindex()] - 0.5
				local v = TB.OtherBot(cand, sp)
				if (v != null) TB.BotSay(v, TBC.EventLine(TBC.Rnd() < 0.6 ? "kick_vote_yes" : "kick_vote_no", null, TB.Ctx(human, v)), false, delay + 3.0)
				TB.BotSay(cand, TBC.EventLine("kick_protest", null, TB.CtxTo(human, cand, sp)), false, delay + 4.5)
				TB.kickVote = { idx = cand.entindex(), from = shown, until = shown + 45.0 }
				return
			}
		}
		if ((hw >= 3 || TB.resp < 20) && TBC.Rnd() < 0.45) {
			local mates = TB.Bots(ht)
			if (mates.len() > 0) {
				TB.kickNextRound = TB.roundNo + 4
				TB.worstRow[human.entindex()] <- 0
				local sp = TBC.Pick(mates)
				if (!TB.BotSay(sp, TBC.EventLine("kick_propose_human", null, TB.Ctx(human, sp)), false, delay + 1.0)) return
				TB.kickHumanT = TB.lastSayT
				local v = TB.OtherBot(sp)
				if (v != null) TB.BotSay(v, TBC.EventLine(TBC.Rnd() < 0.5 ? "kick_vote_yes" : "kick_host", null, TB.Ctx(human, v)), false, delay + 3.0)
				local v2 = TB.OtherBot(sp, v)
				if (v2 != null) TB.BotSay(v2, TBC.EventLine("kick_host", null, TB.Ctx(human, v2)), false, delay + 5.0)
				return
			}
		}
	}
	// тролль шутит над кем-нибудь
	local tr = TB.Troll()
	if (tr != null && TBC.Rnd() < TB_CFG.troll_joke_chance) {
		local t = TB.OtherBot(tr)
		if (t != null) TB.BotSay(tr, TBC.EventLine("troll_joke", null, TB.CtxTo(human, tr, t)), false, delay + 2.0)
	}
}

// ------------------------------------------------------------ think
TB.FunTick <- function(now) {
	if (TB.dropPending != null) TB.DropTick(now)
	if (TB.DuelOn()) { try { TB.DuelEnforce() } catch (e) { printl("[ToxicBots] дуэль: " + e) } }
	else if (TB.duel != null && TB.duel.arm > 0.0) TB.DuelArmTick(now)
	local r = (TB.DuelOn() || TB.dropPending != null || (TB.duel != null && TB.duel.arm > 0.0)) ? 0.3 : null
	local ct = null
	try { ct = TB.CheatTick(now) } catch (e) { printl("[ToxicBots] чит-панель: " + e) }
	if (ct != null && (r == null || ct < r)) r = ct
	return r
}

// ------------------------------------------------------------ ты сменил команду
TB_Events.OnGameEvent_player_team <- function(params) {
	if (!TB_CFG.enabled || !("userid" in params)) return
	if (("disconnect" in params) && params.disconnect) return
	local p = TB.NoteUid(params.userid)
	if (p != null && TB.IsBot(p)) { TB.CheatNewBot(p); return }
	if (p == null) return
	local old = ("oldteam" in params) ? params.oldteam : 0, nw = ("team" in params) ? params.team : 0
	if (old < 2 || nw < 2 || old == nw) return
	TB.Respect(-4)
	TB.lastCmd = null
	local ob = TB.Bots(old), nb = TB.Bots(nw)
	if (ob.len() > 0) { local b = TBC.Pick(ob); TB.BotSay(b, TB.Ev("team_switch_old", b, TB.Ctx(p, b), null, TBC.Rnd() < 0.85), false, 1.0) }
	if (nb.len() > 0 && TBC.Rnd() < 0.7) { local b = TBC.Pick(nb); TB.BotSay(b, TB.Ev("team_switch_new", b, TB.Ctx(p, b)), false, 3.0) }
}

// ------------------------------------------------------------ живой чат: опечатки, маленькие буквы, два сообщения
TB.Humanize <- function(text) {
	local extra = []
	if (!TB_CFG.humanize) return [text, extra]
	local r = TBC.Rnd()
	// разбить на два сообщения по концу предложения
	if (r < 0.15 && text.len() > 90) {
		for (local i = 30; i < text.len() - 30; i++) {
			local c = text[i]
			if ((c == '.' || c == '!' || c == '?') && text[i + 1] == ' ' && text[i - 1] != '.') {
				extra.push(TB.Trim(text.slice(i + 1)))
				text = text.slice(0, (c == '.') ? i : i + 1)
				break
			}
		}
	}
	// опечатка + исправление «*слово»
	if (TBC.Rnd() < TB_CFG.typo_chance) {
		local cps = TBC.Decode(text), st = -1, best = []
		for (local i = 0; i <= cps.len(); i++) {
			local isL = i < cps.len() && TBC.IsCyr(TBC.LowerCp(cps[i]))
			if (isL && st < 0) st = i
			// ники и начало фразы (с большой буквы) не трогаем
			if (!isL && st >= 0) { if (i - st >= 5 && cps[st] == TBC.LowerCp(cps[st])) best.push([st, i]); st = -1 }
		}
		if (best.len() > 0) {
			local w = TBC.Pick(best), j = RandomInt(w[0] + 1, w[1] - 3)
			local word = TBC.Encode(cps.slice(w[0], w[1]))
			if (cps[j] != cps[j + 1]) {
				local t = cps[j]; cps[j] = cps[j + 1]; cps[j + 1] = t
				text = TBC.Encode(cps)
				extra.insert(0, "*" + TBC.Encode(TBC.Decode(word).map(function(c) { return TBC.LowerCp(c) })))
			}
		}
	}
	// без точки в конце, с маленькой буквы
	if (text.len() > 2 && text[text.len() - 1] == '.' && text[text.len() - 2] != '.' && TBC.Rnd() < 0.35) text = text.slice(0, text.len() - 1)
	if (TBC.Rnd() < 0.2) text = TBC.LowFirst(text)
	return [text, extra]
}

// ------------------------------------------------------------ извинения
TB.lastRude <- null      // { idx, name, t } — кого ты последним обосрал
TB.NoteRude <- function(human, bot, a) {
	if (bot == null) return
	TB.lastRude = { idx = bot.entindex(), name = TB.Name(bot), t = Time() }
}
// пара слов подряд: «не купил», «нет денег»
TB.Pair <- function(words, a, bpre) {
	for (local i = 0; i + 1 < words.len(); i++) if (words[i] == a && TB.Pre(words[i + 1], bpre)) return true
	return false
}
TB.AnyPre <- function(words, list) {
	foreach (w in words) foreach (p in list) if (TB.Pre(w, p)) return true
	return false
}
// «случайно», «не знал», «не заметил» — оправдание
TB.IsExcuse <- function(words) {
	if (TB.AnyPre(words, ["хуже", "худш", "слабее", "плохим", "хуёвым", "хуевым"])) return true   // «я даже с более плохим оружием вынес»
	if (TB.AnyPre(words, ["случайн", "нечаян", "неспециальн", "незнал", "незаметил", "рефлекс", "машинальн", "на_автомате"])) return true
	foreach (x in ["знал", "заметил", "специальн", "хотел", "видел", "понял"]) if (TB.Pair(words, "не", x) || TB.Pair(words, "нез", x)) return true
	return TB.Pair(words, "по", "привычк") || TB.Pair(words, "на", "автомат")
}
// «не купил», «не успел», «нет денег», «нету авп»
TB.IsBroke <- function(words) {
	if (TB.AnyPre(words, ["некупил", "неуспел", "нищий", "нищеброд", "бомжую"])) return true
	foreach (x in ["купил", "успел", "хватил", "хватает", "смог", "могу_куп"]) if (TB.Pair(words, "не", x)) return true
	foreach (n in ["нет", "нету", "без"]) {
		foreach (x in ["денег", "денях", "бабла", "бабок", "лаве", "лавэ", "мани", "money"]) if (TB.Pair(words, n, x)) return true
		for (local i = 0; i + 1 < words.len(); i++) if (words[i] == n && TB.WeaponOf(words[i + 1]) != null) return true
	}
	foreach (x in ["денег", "бабла", "бабок"]) { if (TB.Pair(words, x, "нет")) return true; if (TB.Pair(words, x, "нету")) return true }
	return false
}
// «в следующем раунде», «со следующего», «потом»
TB.IsPostpone <- function(words, name) {
	if (TB.AnyPre(words, ["следующ", "некст", "next", "нэкст"])) return true
	if (TB.Pair(words, "со", "след") || TB.Pair(words, "в", "след")) return true
	return (name == "duel" || words.len() <= 3) && TB.AnyPre(words, ["потом", "позже", "попозже"])
}
// «отмена», «передумал», «без дуэли»
TB.IsCancel <- function(words) {
	if (TB.AnyPre(words, ["отмен", "отбой", "передумал", "отставить", "неохота"])) return true
	if (TB.AnyPre(words, ["пошутил", "шучу", "шутка", "прикол", "хватит"]) || TB.Pair(words, "больше", "не")) return true
	return TB.Pair(words, "без", "дуэл") || TB.Pair(words, "не", "хочу") || TB.Pair(words, "не", "буду") || TB.Pair(words, "не", "надо")
}
TB.OnSorry <- function(human, a, polite) {
	local lr = TB.lastRude, words = TB.Words(a)
	local old = lr == null || Time() - lr.t > 120.0
	// «сорян за тот случай» — про нарушенную дуэль
	if (TB.dirty > 0 && (old || TB.AnyPre(words, ["случа", "дуэл", "глок", "крыс", "тогда"]) || TB.Pair(words, "тот", "раз")))
		return TB.ForgiveDirty(human, a, polite)
	if (old) return false
	local b = TB.FindMentioned(a.toks, TB.Bots())
	if (b == null) {
		b = PlayerInstanceFromIndex(lr.idx)
		if (b == null || !b.IsValid() || !TB.IsBot(b) || TB.Name(b) != lr.name) return false
	}
	TB.lastRude = null
	local p = ((TB.resp >= 25) ? 0.8 : 0.45) + (polite ? 0.1 : 0.0)
	local ok = TBC.Rnd() < p
	if (ok) TB.Respect(10)
	TB.BotSay(b, TBC.EventLine(ok ? "sorry_accept" : "sorry_reject", null, TB.Ctx(human, b)), false)
	TB.Talked(b)
	return true
}

// ------------------------------------------------------------ разговор про дуэль
// кто отвечает: названный по нику -> кого убили не тем стволом -> кто соглашался
TB.DuelSpeaker <- function(human, a) {
	local b = TB.FindMentioned(a.toks, TB.Bots())
	if (b != null) return b
	foreach (i in [(Time() - TB.dirtyT < 45.0) ? TB.dirtyBot : -1, (TB.duel != null) ? TB.duel.armBot : -1]) {
		if (i <= 0) continue
		local p = PlayerInstanceFromIndex(i)
		if (p != null && p.IsValid() && TB.IsBot(p)) return p
	}
	return TB.PickBot(a, human, false)
}
TB.MODAL <- {}
foreach (w in ["можно", "нельзя", "без", "не", "правило", "правила", "разрешено", "разрешаю", "запрещено", "норм", "тоже", "но"]) TB.MODAL[w] <- 1
// «так мы на ножах или чё?» -> "status", «чё сразу на диглах?» -> "why", иначе null
TB.DuelQuestion <- function(words, text) {
	local q = text.find("?") != null
	local hm = TB.AnyW(words, ["чё", "че", "чо", "что", "чего", "шо"])
	if (TB.AnyPre(words, ["почему", "зачем", "нахуя", "нахера", "нафига", "накой"]) || (hm && TB.AnyW(words, ["сразу"]))) return "why"
	if ((TB.AnyW(words, ["или"]) && (q || hm)) || TB.Pair(words, "так", "мы") || (q && TB.Pair(words, "мы", "на")) || TB.Pair(words, "на", "чем") || TB.Pair(words, "на", "чём")) return "status"
	return null
}
TB.AnyW <- function(words, list) {
	foreach (w in words) foreach (x in list) if (w == x) return true
	return false
}
// «один на один», «1на1», «раз на раз», «пвп»
TB.IsOneVOne <- function(words) {
	if (TB.AnyW(words, ["1на1", "1v1", "1x1", "1х1", "пвп", "pvp"])) return true
	for (local i = 0; i + 2 < words.len(); i++)
		if (words[i + 1] == "на" && ((TB.Pre(words[i], "один") && TB.Pre(words[i + 2], "один")) || (words[i] == "1" && words[i + 2] == "1") || (words[i] == "раз" && words[i + 2] == "раз"))) return true
	return false
}
// живой бот-противник (для «давай дуэль» без ника)
TB.AliveFoe <- function(a, human) {
	local b = TB.FindMentioned(a.toks, TB.Bots())
	if (b != null) return b
	local foes = []
	foreach (x in TB.Bots(human.GetTeam() == 2 ? 3 : 2)) if (TB.Alive(x)) foes.push(x)
	return (foes.len() > 0) ? TBC.Pick(foes) : TB.PickBot(a, human, false)
}
TB.DSay <- function(b, ev, ctx) { TB.BotSay(b, TBC.EventLine(ev, null, ctx), false); TB.Talked(b) }
TB.DuelTalk <- function(human, a, words, name, rude, polite, text = "") {
	local d = TB.duel, o = TB.offer, now = Time()
	if (o != null && now > o.until) { TB.offer = null; o = null }
	if (o != null && now < o.from) o = null   // ещё не появилось в чате
	local weps = TB.ParseWeapons(a), naW = false
	foreach (p in weps) if (p.na && !(("w" in p) && p.w.cat == "grenade")) naW = true
	local onev = TB.IsOneVOne(words)
	// «на калашах», «все на awp» — это про дуэль, даже если тема распозналась иначе
	local isDuel = name == "duel" || onev || (naW && name != "drop")
	local pos = [], neg = []
	if (isDuel) foreach (p in weps) {
		if (("w" in p) && p.w.cat == "grenade") continue   // гранаты — это правило, а не дуэль
		if (p.neg) neg.push(p); else pos.push(p)
	}
	local rules = TB.DuelRules(words)
	if (rules != null && !isDuel) {
		local modal = false
		foreach (w in words) if (w in TB.MODAL) modal = true
		if (!modal) rules = null
	}
	local knifeW = TB.AnyPre(words, ["нож"])
	// «чё вы все на ножах», «мы больше не на ножах»
	local complain = knifeW && TB.AnyW(words, ["вы", "все", "чё", "че", "чо", "опять", "нахуя", "нахера", "зачем", "почему", "заебали"]) && !TB.AnyW(words, ["давай", "давайте", "го", "погнали"])
	local broke = TB.IsBroke(words), post = TB.IsPostpone(words, name)
	local cancel = TB.IsCancel(words) && (isDuel || knifeW || d != null || o != null)
	local q = (isDuel || complain) ? TB.DuelQuestion(words, text) : null
	local excuse = TB.IsExcuse(words) || name == "sorry"
	local negOnly = neg.len() > 0 && pos.len() == 0 && !onev
	if (isDuel) TB.offerNextRound = TB.Max(TB.offerNextRound, TB.roundNo + 2)

	// --- дуэли нет и никто не предлагал
	if (d == null && o == null) {
		if (complain || (cancel && knifeW)) {
			// боты всё ещё на ножах, хотя дуэли нет — вернуть им стволы
			TB.AllWeapons()
			local b = TB.AliveFoe(a, human)
			if (b != null) TB.DSay(b, "duel_unstuck", TB.Ctx(human, b))
			return true
		}
		if (!isDuel) return false
		local b = TB.PickBot(a, human, false)
		if (b == null) return true
		if (q == "status") { TB.DSay(b, "duel_status_none", TB.Ctx(human, b)); return true }
		if (q == "why" || negOnly || cancel) { TB.DSay(b, "duel_cancel_none", TB.Ctx(human, b)); return true }
		TB.OnDuel(human, a, rude, polite)
		return true
	}
	// --- бот предложил дуэль, ты ответил не просто «да/нет»
	if (d == null) {
		local b = PlayerInstanceFromIndex(o.bot)
		if (b == null || !b.IsValid() || !TB.IsBot(b)) { TB.offer = null; return false }
		local c = TB.Ctx(human, b); c.duel <- o.spec.disp
		if (q == "why") { TB.DSay(b, "duel_why", c); return true }
		if (q == "status") { TB.DSay(b, "duel_status_offer", c); return true }
		if (cancel || negOnly) {
			TB.offer = null
			TB.BotSay(b, TB.DEv("duel_offer_declined", b, c, o.spec, true), false)
			TB.Respect(-2); TB.Talked(b)
			return true
		}
		local spec = onev ? TB.OneVOneSpec(b, a) : ((pos.len() > 0) ? TB.SpecOf(pos) : o.spec)
		if (rules != null) TB.ApplyRules(spec, rules)
		if (broke || post) { TB.offer = null; TB.StartDuel(spec, b, human, "duel_offer_accepted", "duel_postpone", true); return true }
		if (pos.len() > 0 || rules != null || onev) {
			TB.offer = null
			TB.StartDuel(spec, b, human, "duel_offer_accepted", "duel_accept_next")
			if (rules != null) { local c2 = TB.DuelCtx(TB.Ctx(human, b)); c2.rules = TB.RulesText(rules); TB.BotSay(b, TBC.EventLine("duel_rule_ok", null, c2), false) }
			return true
		}
		return false
	}
	// --- дуэль договорена (идёт сейчас или со следующего раунда)
	local recent = now - TB.dirtyT < 45.0 && TB.dirty > 0
	if (!(broke || post || (excuse && recent) || cancel || complain || negOnly || pos.len() > 0 || rules != null || isDuel)) return false
	local b = TB.DuelSpeaker(human, a)
	if (b == null) return false
	local ctx = TB.DuelCtx(TB.Ctx(human, b))
	TB.Talked(b)
	if (q == "why") { TB.DSay(b, "duel_why_agreed", ctx); return true }
	if (q == "status" || (complain && !cancel)) { TB.DSay(b, "duel_status", ctx); return true }
	if (broke || post) {
		// «не купил AWP» — верим: начнём со следующего раунда, а килл «не тем» прощаем
		local forgive = broke && recent
		if (forgive) { TB.dirty--; TB.dirtyT = -100.0; TB.Respect(15); TB.CancelTag("dirty") }
		TB.DuelPostpone()
		TB.DSay(b, forgive ? "duel_postpone_forgive" : "duel_postpone", ctx)
		return true
	}
	if (excuse && recent) {
		TB.dirtyT = -100.0
		local ok = TBC.Rnd() < ((TB.resp >= 30) ? 0.7 : 0.35) + (polite ? 0.15 : 0.0)
		if (ok) { TB.dirty--; TB.Respect(12); TB.CancelTag("dirty") }
		TB.DSay(b, ok ? "duel_forgive" : "duel_forgive_no", ctx)
		return true
	}
	if (cancel || negOnly) {
		// «не на AWP», а договорились на ножах — это просто уточнение
		local same = cancel
		foreach (p in neg) if (TB.SpecOf([p]).disp == d.disp) same = true
		if (!same) { TB.DSay(b, "duel_clarify", ctx); return true }
		TB.DuelStop()
		TB.DSay(b, "duel_cancel", ctx)
		return true
	}
	if (pos.len() > 0 || onev) {
		local spec = onev ? TB.OneVOneSpec(b, a) : TB.SpecOf(pos)
		spec.bomb = d.bomb
		if (rules != null) TB.ApplyRules(spec, rules)
		if (spec.disp != d.disp) {
			TB.DuelReplace(spec)
			ctx.duel = d.disp
			TB.DSay(b, "duel_switch", ctx)
			if (rules != null) { ctx.rules = TB.RulesText(rules); TB.BotSay(b, TBC.EventLine("duel_rule_ok", null, ctx), false) }
			return true
		}
	}
	if (rules != null) {
		TB.ApplyRules(d, rules)
		if (d.active) TB.DuelActivate()
		ctx.rules = TB.RulesText(rules)
		TB.DSay(b, "duel_rule_ok", ctx)
		return true
	}
	TB.DSay(b, "duel_already", ctx)
	return true
}
TB.Max <- function(a, b) { return a > b ? a : b }
// простить старое нарушение: «да сорян за тот случай»
TB.ForgiveDirty <- function(human, a, polite) {
	local b = TB.FindMentioned(a.toks, TB.Bots())
	if (b == null && TB.dirtyBot > 0) { local p = PlayerInstanceFromIndex(TB.dirtyBot); if (p != null && p.IsValid() && TB.IsBot(p)) b = p }
	if (b == null) b = TB.PickBot(a, human, false)
	if (b == null) return false
	local ok = TBC.Rnd() < ((TB.resp >= 30) ? 0.75 : 0.4) + (polite ? 0.1 : 0.0)
	if (ok) { TB.dirty = 0; TB.dirtyT = -100.0; TB.Respect(10); TB.CancelTag("dirty") }
	TB.DSay(b, ok ? "duel_forgive" : "duel_forgive_no", TB.DuelCtx(TB.DuelRecallCtx(human, b)))
	return true
}
