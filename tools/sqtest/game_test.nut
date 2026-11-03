// Эмуляция VScript API CS:S для проверки main.nut без игры
srand(12345);
local DIR = vargv[0]
::NOW <- 0.0
::RandomFloat <- function(a, b) { return a + (b - a) * rand() / RAND_MAX.tofloat() }
::RandomInt <- function(a, b) { return a + rand() % (b - a + 1) }
::Time <- function() { return NOW }
::printl <- function(s) { print(s + "\n") }
::IncludeScript <- function(n, scope = null) { dofile(DIR + "/" + n + ".nut") }
::GetMapName <- function() { return "de_dust2" }
::VOICE <- null
::FileToString <- function(f) { return VOICE }
::StringToFile <- function(f, s) { print("   TTS-FILE<" + f + "> last: " + s.slice(s.slice(0, s.len()-1).len() > 0 ? 0 : 0).len() + " bytes\n") }
::PrecacheSound <- function(s) { return true }
::EmitSoundEx <- function(t) { print("   SOUND " + t.sound_name + " from " + t.entity.name + "\n") }
class Vector {
	x = 0.0; y = 0.0; z = 0.0
	constructor(a = 0.0, b = 0.0, c = 0.0) { x = a; y = b; z = c }
	function _add(o) { return Vector(x + o.x, y + o.y, z + o.z) }
	function _sub(o) { return Vector(x - o.x, y - o.y, z - o.z) }
	function _mul(k) { return Vector(x * k, y * k, z * k) }
	function Length() { return sqrt(x * x + y * y + z * z) }
	function _tostring() { return "(" + x.tointeger() + " " + y.tointeger() + " " + z.tointeger() + ")" }
}
class FakeWpn {
	cls = ""; owner = null; valid = true
	constructor(c, o) { cls = c; owner = o }
	function IsValid() { return valid }
	function GetClassname() { return cls }
	function Kill() { valid = false; print("   KILL " + cls + " у " + owner.name + "\n"); owner.wpn.remove(owner.wpn.find(this)) }
}
class QAngle {
	x = 0.0; y = 0.0; z = 0.0
	constructor(a = 0.0, b = 0.0, c = 0.0) { x = a; y = b; z = c }
}
::TraceLine <- function(a, b, ig) { return 1.0 }
::VELS <- 0
::SNAPS <- 0
class FakeEnt {
	idx = 0; team = 0; bot = false; name = ""; alive = 1; scope = null; valid = true; pos = null; wpn = null; money = 800
	hp = 100; vel = null; lag = 1.0
	function GetHealth() { return hp }
	function SetHealth(v) { hp = v }
	function TakeDamage(d, t, a) {
		hp -= d
		if (hp <= 0 && alive) { alive = 0; print("   DAMAGE-KILL " + name + " от " + a.name + "\n"); ::EV.player_death({ userid = idx, attacker = a.idx, weapon = "world", headshot = false }) }
	}
	function EyePosition() { return pos + Vector(0, 0, 64) }
	function EyeAngles() { return QAngle(0, 0, 0) }
	function GetAngles() { return QAngle(0, 0, 0) }
	function GetAbsVelocity() { return (vel != null) ? vel : Vector(0, 0, 0) }
	function SetAbsVelocity(v) { vel = v; ::VELS++ }
	function SnapEyeAngles(a) { ::SNAPS++ }
	function GetActiveWeapon() { return null }
	constructor(i, t, b, n) { idx = i; team = t; bot = b; name = n; pos = Vector(i * 100, 0, 0); wpn = [] }
	function GetOrigin() { return pos }
	function Give(c) { wpn.push(FakeWpn(c, this)) }
	function IsValid() { return valid }
	function GetTeam() { return team }
	function entindex() { return idx }
	function ValidateScriptScope() { if (scope == null) scope = {} }
	function GetScriptScope() { return scope }
}
::PL <- [null,
	FakeEnt(1, 2, false, "Игрок"), FakeEnt(2, 2, true, "Vasya"), FakeEnt(3, 2, true, "Petya"),
	FakeEnt(4, 3, true, "Brett"), FakeEnt(5, 3, true, "Vladimir"), FakeEnt(6, 3, true, "Kirk")]
::SCORE <- {[2] = 0, [3] = 0}
::MaxClients <- function() { return 32.0 }
::PlayerInstanceFromIndex <- function(i) { return (i < PL.len()) ? PL[i] : null }
::GetPlayerFromUserID <- function(u) { return PlayerInstanceFromIndex(u) }
::IsPlayerABot <- function(p) { return p.bot }
::GetListenServerHost <- function() { return PL[1] }
::NetProps <- {
	GetPropString = function(e, n) { return e.name }
	GetPropEntityArray = function(e, n, i) { return (i < e.wpn.len()) ? e.wpn[i] : null }
	SetPropFloat = function(e, n, v) { if (n == "m_flLaggedMovementValue") e.lag = v }
	SetPropInt = function(e, n, v) { if (n == "m_iTeamNum") { print("   TEAM " + e.name + " " + e.team + " -> " + v + "\n"); e.team = v; return } if (n == "m_iAccount") { print("   MONEY " + e.name + " " + e.money + " -> " + v + "\n"); e.money = v } }
	GetPropInt = function(e, n) {
		if (n == "m_iAccount") return e.money
		if (n == "m_lifeState") return e.alive ? 0 : 2
		if (n == "m_fFlags") return 1
		if (n == "m_nButtons") return 1
		if (n == "m_iHealth") return e.hp
		if (n == "m_iTeamNum") return e.team
		if (n == "m_iScore") return SCORE[e.team]
		return 0
	}
}
// консоль как в игре: команды применяются только на следующем кадре (run)
::CV <- {}
::CVQ <- []
::Convars <- { GetInt = function(n) { if (n in CV) return CV[n]; return n == "mp_maxrounds" ? 4 : (n.find("bot_allow") == 0 ? 1 : 0) },
	GetStr = function(n) { return "always" } }
::SendToServerConsole <- function(c) { print("   SERVERCMD " + c + "\n"); CVQ.push(c) }
::CVFlush <- function() {
	foreach (c in CVQ) foreach (part in split(c, ";")) {
		local w = split(part, " ")
		if (w.len() == 2 && w[0].find("bot_allow") == 0) CV[w[0]] <- w[1].tointeger()
	}
	CVQ = []
}
::KNIVES <- function() { local z = 0; foreach (k, v in CV) if (k.find("bot_allow") == 0 && v == 0) z++; return z }
::TEAMS <- [FakeEnt(50, 2, false, "t"), FakeEnt(51, 3, false, "ct")]
::BOMB <- false
::Entities <- { FindByClassname = function(prev, cls) {
	if (cls == "planted_c4") return (BOMB && prev == null) ? TEAMS[0] : null
	if (prev == null) return TEAMS[0]
	if (prev == TEAMS[0]) return TEAMS[1]
	return null } }
::THINK <- null
::SpawnEntityFromTable <- function(c, t) {
	if (c.find("weapon_") == 0) { print("   SPAWN " + c + " at " + t.origin + "\n"); return FakeWpn(c, PL[1]) }
	return FakeEnt(60, 0, false, "think") }
::NEXT <- 0.0
::THINKS <- 0
::AddThinkToEnt <- function(e, f) { THINK = e.scope[f]; NEXT = NOW + 0.1 }
::SendGlobalGameEvent <- function(n, t) { print("   EVENT " + n + " userid=" + t.userid + " slot=" + t.slot + "\n"); return true }
::ClientPrint <- function(p, d, s) {
	if (d == 4) { print("   CENTER[" + p.name + "] " + s + "\n"); return }
	local o = ""
	foreach (i, c in s) { if (c == 7) { o += "<"; } else if (c == 1) o += ">"; else if (c >= 32 || c < 0) o += c.tochar() }
	print("   CHAT[" + p.name + "] " + o + "\n")
}
::EV <- {}
::__CollectGameEventCallbacks <- function(scope) { foreach (k, v in scope) EV[k.slice(12)] <- v }
dofile(DIR + "/mapspawn.nut")
// think вызывается так, как попросил скрипт (return = через сколько секунд)
::run <- function(sec) { local end = NOW + sec; while (NOW < end) { NOW += 0.05; CVFlush(); if (THINK && NOW >= NEXT - 0.001) { THINKS++; NEXT = NOW + THINK() } } }
::say <- function(t) { print("Игрок: " + t + "\n"); EV.player_say({ userid = 1, text = t }); run(8) }
TB_CFG.debug = false
EV.round_start({})
run(4)
foreach (t in ["ты еблан конченный", "что за хуйня, блять", "Vasya ты чё такой борзый", "иди нахуй", "го б рашим",
	"ty eblan", "мамку твою", "ну вы раки тиммейты", "!tb stat"]) say(t)
print("--- бот убил игрока в голову\n")
EV.player_hurt({ userid = 1, attacker = 4, dmg_health = 100 })
EV.player_death({ userid = 1, attacker = 4, weapon = "ak47", headshot = true })
run(6)
print("--- игрок убил бота\n")
EV.player_hurt({ userid = 5, attacker = 1, dmg_health = 100 })
EV.player_death({ userid = 5, attacker = 1, weapon = "deagle", headshot = false })
EV.player_hurt({ userid = 6, attacker = 2, dmg_health = 80 })
run(6)
print("--- раунд проигран (T)\n")
SCORE[3] = 1
EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" })
run(15)
print("--- голос\n")
VOICE = "1\tстарое\n"
run(1)
VOICE = "1\tстарое\n2\tблять ты тупой бот\n"
run(8)
print("--- конец матча\n")
SCORE[3] = 3; SCORE[2] = 0
EV.round_start({})
EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" })
SCORE[2] = 1
run(20)

print("--- новое: приказы, настроение, счёт, поддавки\n")
EV.round_start({})
EV.player_spawn({ userid = 1 })
run(3)
TB_CFG.debug = true
foreach (t in ["пацаны давайте за мной на б пожалуйста", "за мной на б, еблан", "прикройте меня плиз", "дефузьте бомбу"]) say(t)
BOMB = true
PL[1].team = 3; PL[2].team = 3; PL[4].team = 2   // игрок за CT
say("ребят дефузьте бомбу")
PL[1].team = 2; PL[2].team = 2; PL[4].team = 3
BOMB = false
foreach (t in ["чуваки давайте быть командой а то пиздец анрил", "у тебя 0 килов лол", "Kirk посмотри на свой счёт, 0-5", "я поддаюсь, ща без поддавок", "!tb mood"]) say(t)
print("--- раунд: игрок раздал 3 кила после «поддаюсь»\n")
foreach (v in [4, 5, 6]) EV.player_death({ userid = v, attacker = 1, weapon = "ak47", headshot = false })
run(4)
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(14)
print("--- раунд: хороший раунд без поддавок\n")
EV.round_start({})
foreach (v in [4, 5]) EV.player_death({ userid = v, attacker = 1, weapon = "ak47", headshot = false })
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(14)
print("--- простой (тишина 60 с): вызовов think = ")
THINKS = 0
run(60)
print(THINKS + "\n")

print("\n=============== новое 2: перепалки, тролль, дроп, дуэли, читы, кики\n")
TB_CFG.debug = false
TB.resp = 60
foreach (p in PL) if (p != null) { p.wpn = []; p.Give("weapon_knife") }
PL[2].Give("weapon_ak47"); PL[2].Give("weapon_glock")
PL[3].Give("weapon_glock")
PL[4].Give("weapon_m4a1"); PL[4].Give("weapon_usp"); PL[5].Give("weapon_awp"); PL[6].Give("weapon_deagle")
PL[2].pos = Vector(150, 0, 0); PL[3].pos = Vector(2000, 0, 0)
::SAYS <- function(arr) { foreach (t in arr) say(t) }
print("--- тролль = " + (TB.Troll() != null ? TB.Troll().name : "нет") + "\n")
SAYS(["чё ты такой слабый", "Vasya ты нуб ебаный", "противник хорошо играет", "ты переобулся", "дай денег"])
print("--- защита бомбы\n")
BOMB = true
SAYS(["пацаны дефайте бомбу", "ну вы и слабаки"])
BOMB = false
say("охраняйте бомбу ребят")
PL[1].team = 3; PL[2].team = 3; PL[4].team = 2
say("пацаны держим плент")
BOMB = true
say("дефайте бомбу ребят")
BOMB = false
PL[1].team = 2; PL[2].team = 2; PL[4].team = 3
print("--- дроп\n")
TB.resp = 80
SAYS(["Vasya дропни калаш пж", "Petya скинь ствол плиз", "Petya дай авп"])
PL[3].pos = Vector(200, 0, 0)
run(2)
SAYS(["Brett дропни эмку", "Vasya дай калаш"])
print("--- смена команды\n")
EV.player_team({ userid = 1, team = 3, oldteam = 2, disconnect = false })
run(8)
print("--- дуэль на ножах (сразу)\n")
EV.round_start({})
run(2)
say("давай на ножах")
run(1)
print("   у Brett: "); foreach (w in PL[4].wpn) print(w.cls + " "); print("\n")
PL[4].money = 300; run(1)
print("--- игрок убил с AWP в ножевом раунде\n")
EV.player_death({ userid = 5, attacker = 1, weapon = "awp", headshot = true })
run(8)
say("ты еблан")
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(12)
EV.round_start({})
run(6)
print("--- дуэль на диглах в середине раунда -> со следующего\n")
NOW += 40
say("го раунд на диглах")
say("давай на диглах")
EV.round_start({})
run(3)
print("   у Kirk: "); foreach (w in PL[6].wpn) print(w.cls + " "); print("   у Vladimir: "); foreach (w in PL[5].wpn) print(w.cls + " "); print("\n")
EV.player_death({ userid = 6, attacker = 1, weapon = "deagle", headshot = false })
run(4)
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(10)
EV.round_start({})
run(4)
print("--- бот предлагает дуэль\n")
TB_CFG.duel_offer_chance = 1.0
TB.duel = null
EV.round_start({})
run(5)
say("да")
run(2)
TB_CFG.duel_offer_chance = 0.07
EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" })
run(10)
EV.round_start({})
run(4)
print("--- читы: 3 хедшота подряд, эйс\n")
TB.accuseNext = 0
foreach (v in [4, 5, 6]) { EV.player_death({ userid = v, attacker = 1, weapon = "ak47", headshot = true }); run(1) }
run(6)
print("--- кик\n")
TB.resp = 90
say("кикните Kirk он дно")
run(10)
say("кикни")
print("--- бот убил бота\n")
TB_CFG.bot_kill_bot_chance = 1.0
EV.player_death({ userid = 2, attacker = 4, weapon = "m4a1", headshot = false })
run(5)
print("--- бот худший 3 раунда подряд -> предложат кик\n")
TB.kickNextRound = 0
foreach (i in [1, 2, 3]) {
	EV.round_start({})
	EV.player_hurt({ userid = 4, attacker = 3, dmg_health = 50 })
	EV.player_hurt({ userid = 5, attacker = 2, dmg_health = 90 })
	EV.player_hurt({ userid = 6, attacker = 1, dmg_health = 90 })
	EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" })
	run(12)
}
say("да")
run(10)
print("--- конец новое 2\n")
print("--- дроп издалека\n")
local oc = TB.ObeyChance
TB.ObeyChance = function(r, p) { return 1.0 }
PL[3].alive = 1; PL[3].Give("weapon_mp5navy"); PL[3].pos = Vector(3000, 0, 0); PL[1].team = 2; PL[3].team = 2
say("Petya скинь мп5 пж")
run(3)
PL[3].pos = Vector(300, 0, 0)
run(3)
TB.ObeyChance = oc
print("--- конец\n")

print("\n=============== новое 3: по логу игрока\n")
TB.duel = null; TB.offer = null; TB.dirty = 0; TB.resp = 60; TB.lastCmd = null; TB.kickVote = null
foreach (p in PL) if (p != null) { p.alive = 1; p.valid = true }
PL[1].team = 2; PL[2].team = 2; PL[3].team = 2; PL[4].team = 3; PL[5].team = 3; PL[6].team = 3
EV.round_start({})
run(3)
print("--- извинения\n")
say("Brett ты еблан конченый")
say("бля сорян")
say("Kirk ты тупой")
run(5)
say("сорри Kirk")
print("--- похвала / самокритика\n")
SAYS(["ты просто босс", "Brett легенда", "я слил", "ну я дно", "я уебаном был", "ron плачет"])
print("--- кик без ника\n")
SAYS(["го кого то кикнем?", "Kick"])
print("--- приказ, потом «я слил» (не должно быть «ты сам позвал»), потом «вы слабаки»\n")
TB.ObeyChance = function(r, p) { return 1.0 }
say("за мной на б")
say("я слил")
say("ну вы слабаки")
TB.ObeyChance = oc
print("--- «так я заложил»\n")
BOMB = true; EV.bomb_planted({ userid = 1 })
say("так я заложил")
BOMB = false
print("--- дуэль на AWP в начале раунда, AWP у игрока нет -> ждут, пока купит\n")
EV.round_start({})
run(2)
foreach (p in PL) if (p != null) { p.wpn = []; p.Give("weapon_knife") }
PL[1].Give("weapon_glock"); PL[4].Give("weapon_m4a1"); PL[5].Give("weapon_awp")
say("давай на авп")
print("   duel.active = " + TB.duel.active + "\n")
PL[1].Give("weapon_awp")
run(2)
print("   купил -> duel.active = " + TB.duel.active + "\n")
print("--- убил с глока, потом «я его не купил» -> прощают и переносят\n")
PL[1].wpn = []; PL[1].Give("weapon_knife"); PL[1].Give("weapon_glock")
EV.player_death({ userid = 4, attacker = 1, weapon = "glock", headshot = false })
run(6)
print("   dirty = " + TB.dirty + "\n")
say("я его не купил")
print("   dirty = " + TB.dirty + " active = " + TB.duel.active + "\n")
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(10)
print("--- следующий раунд: дуэль стартует, AWP кладут игроку под ноги\n")
EV.round_start({})
run(4)
print("   active = " + TB.duel.active + "\n")
print("--- «не на ножах» во время AWP-дуэли -> уточнение; «не на авп» -> отмена\n")
say("не на ножах")
say("не на авп")
print("   duel = " + TB.duel + "\n")
say("не на ножах")
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" })
run(10)
print("--- ножи + правило «бомбу можно ставить», потом «без бомбы», игрок заложил\n")
EV.round_start({})
run(2)
PL[4].Give("weapon_c4")
say("ну кста давайте правило бомбу можно ставить во время на ножах")
print("   bomb = " + TB.duel.bomb + "\n")
say("не, давайте без бомбы")
print("   bomb = " + TB.duel.bomb + "\n")
run(1)
EV.bomb_planted({ userid = 1 })
run(6)
print("   dirty = " + TB.dirty + "\n")
print("--- оправдание после нарушения\n")
EV.player_death({ userid = 5, attacker = 1, weapon = "glock", headshot = false })
run(6)
say("сорри случайно пистолет достал")
print("   dirty = " + TB.dirty + "\n")
say("так я нез знал")
print("--- гранаты можно, несколько стволов\n")
say("гранаты тоже можно")
TB.DuelStop(); TB.dirty = 0; TB.resp = 70
say("давай на диглах и ножах")
print("   duel = " + (TB.duel != null ? TB.duel.disp + " give=" + TB.duel.give : "null") + "\n")
TB.DuelStop()
print("--- бот предлагает, ответ «давай в следующем раунде»\n")
TB.MaybeOffer = TB.MaybeOffer
TB_CFG.duel_offer_chance = 1.0
EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" })
run(10)
EV.round_start({})
run(5)
TB_CFG.duel_offer_chance = 0.07
say("давай в следующем раунде")
print("   duel = " + (TB.duel != null ? TB.duel.disp + " active=" + TB.duel.active : "null") + "\n")
TB.DuelStop()
print("--- кикнутый бот: его реплика не звучит от новенького\n")
TB.BotSay(PL[6], "ЭТО НЕ ДОЛЖНО ПОЯВИТЬСЯ", false, 0.0, true)
PL[6].name = "Jon"
run(8)
PL[6].name = "Kirk"
print("--- склонения: " + TB.Clean("1 килов, 3 килов, 12 килов, 22 смертей, 5 фрагов, 21 фрагов") + "\n")
print("--- конец новое 3\n")

print("\n=============== новое 4: второй лог игрока\n")
TB.DuelStop(); TB.offer = null; TB.dirty = 0; TB.resp = 70; run(2)
print("--- после ножевой дуэли со сменой оружия боты не должны остаться на ножах\n")
say("давай на ножах")
run(3)
print("   duel = " + (TB.duel != null ? TB.duel.disp + " active=" + TB.duel.active : "null") + " zeros=" + KNIVES() + "\n")
say("не, давай на диглах")
run(1)
say("ладно давай опять на ножах")
run(3)
EV.round_end({ winner = 3, reason = 8, message = "#CTs_Win" }); run(8)
EV.round_start({}); run(3)
print("   duel = " + (TB.duel != null ? TB.duel.disp : "null") + " zeros=" + KNIVES() + " (должно быть 0)\n")
print("--- «чё вы все на ножах», дуэли нет\n")
CV.bot_allow_rifles <- 0; CV.bot_allow_pistols <- 0
say("а чё вы бля все на ебанных ножах")
run(4)
print("   zeros=" + KNIVES() + " (должно быть 0)\n")
print("--- вопросы про дуэль\n")
say("давай на диглах"); run(3)
say("так мы на диглах или чё?"); run(3)
say("чё сразу на диглах?"); run(3)
say("мы больше не на диглах, хватит"); run(3)
print("   duel = " + (TB.duel != null ? TB.duel.disp : "null") + "\n")
print("--- мёртвый бот соглашается\n")
PL[5].alive = false
say("vladimir давай на ножах"); run(3)
print("   duel = " + (TB.duel != null ? TB.duel.disp + " active=" + TB.duel.active : "null") + "\n")
TB.DuelStop(); PL[5].alive = true
PL[6].alive = false
say("kirk ты где?"); run(3)
PL[6].alive = true
print("--- один на один\n")
say("brett одина на один?"); run(3)
print("   duel = " + (TB.duel != null ? TB.duel.disp + " free=" + ("free" in TB.duel) + " zeros=" + KNIVES() : "null") + "\n")
TB.duel.active = true
EV.player_death({ userid = 1, attacker = 6, weapon = "ak47", headshot = false }); run(5)
say("kirk не вмешивайся"); run(3)
TB.DuelStop()
print("--- убил хуже договорённого\n")
say("давай на диглах"); run(3)
TB.duel.active = true
EV.player_death({ userid = 5, attacker = 1, weapon = "glock", headshot = false }); run(5)
print("   dirty = " + TB.dirty + "\n")
EV.player_death({ userid = 4, attacker = 1, weapon = "awp", headshot = false }); run(5)
print("   dirty = " + TB.dirty + "\n")
TB.DuelStop()
TB.roundNo += 4
say("давай на ножах"); run(3)
say("да сорян за тот случай"); run(3)
print("   dirty = " + TB.dirty + "\n")
TB.DuelStop(); TB.dirty = 0
print("--- болтовня отменяется, когда пишешь\n")
TB.SayChat(PL[2], "ЭТО ДОЛЖНО ОТМЕНИТЬСЯ", false, 9.0)
say("ну чё пацаны")
run(12)
print("--- конец новое 4\n")

print("\n=============== новое 5: чит-панель\n")
::TEAMSTR <- function() { local o = ""; for (local i = 2; i <= 6; i++) o += PL[i].name + "=" + PL[i].team + " "; return o }
::REVIVE <- function() { for (local i = 1; i <= 6; i++) { PL[i].alive = 1; PL[i].hp = 100 } }
TB.DuelStop(); TB.offer = null; TB.dirty = 0; REVIVE(); run(30)
say("!c")
say("!c 4")
print("--- боты стреляют в бессмертного\n")
for (local i = 0; i < 4; i++) { EV.player_hurt({ userid = 1, attacker = 4, dmg_health = 90 }); PL[1].hp -= 90; run(1.5) }
run(4)
print("   hp=" + PL[1].hp + " sus=" + TB.sus + " stage=" + TB.susStage + "\n")
print("--- аимбот: одно попадание = смерть\n")
say("!c 1")
EV.player_hurt({ userid = 5, attacker = 1, dmg_health = 20 }); run(5)
EV.player_hurt({ userid = 6, attacker = 1, dmg_health = 20 }); run(5)
print("   snaps=" + SNAPS + " sus=" + TB.sus + " stage=" + TB.susStage + "\n")
print("--- ВХ-радар и спидхак\n")
say("!c 2")
say("!c 3")
print("   lag=" + PL[1].lag + "\n")
run(10)
say("я не читер это скилл")
run(15)
print("   sus=" + TB.sus.tointeger() + " stage=" + TB.susStage + " mode=" + TB.cheatMode + "\n   " + TEAMSTR() + "\n")
run(25)
print("   sus=" + TB.sus.tointeger() + " stage=" + TB.susStage + " mode=" + TB.cheatMode + " ignore=" + TB.cheatIgnore + "\n   " + TEAMSTR() + "\n")
// VELS считается за всё время
run(10)
print("   хоровод: vel-вызовов=" + VELS + " mode=" + TB.cheatMode + " ignore=" + TB.cheatIgnore + "\n   " + TEAMSTR() + "\n")
run(15)
print("   после хоровода: mode=" + TB.cheatMode + " ignore=" + TB.cheatIgnore + "\n   " + TEAMSTR() + "\n")
print("--- УБИТЬ ВСЕХ НА КАРТЕ\n")
REVIVE()
say("!c 6")
run(15)
print("   killall=" + TB.cheatKillAll + " alive=" + PL[2].alive + PL[3].alive + PL[4].alive + PL[5].alive + PL[6].alive + "\n")
EV.round_end({ winner = 2, reason = 9, message = "#Terrorists_Win" }); run(8)
REVIVE(); EV.round_start({}); run(12)
print("   новый раунд: mode=" + TB.cheatMode + "\n")
print("--- второй раз: кто-то ливает\n")
say("!c 6")
run(15)
print("--- всё выключил, ждём\n")
say("!c 0")
REVIVE()
run(150)
print("   прыжков-вызовов за всё время=" + VELS + " поворотов=" + SNAPS + "\n   sus=" + TB.sus.tointeger() + " stage=" + TB.susStage + " mode=" + TB.cheatMode + " ignore=" + TB.cheatIgnore + " lag=" + PL[1].lag + " hp=" + PL[1].hp + "\n   " + TEAMSTR() + "\n")
print("--- конец новое 5\n")
