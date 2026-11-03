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
class FakeEnt {
	idx = 0; team = 0; bot = false; name = ""; alive = 1; scope = null; valid = true; pos = null; wpn = null; money = 800
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
	SetPropInt = function(e, n, v) { if (n == "m_iAccount") { print("   MONEY " + e.name + " " + e.money + " -> " + v + "\n"); e.money = v } }
	GetPropInt = function(e, n) {
		if (n == "m_iAccount") return e.money
		if (n == "m_lifeState") return e.alive ? 0 : 2
		if (n == "m_iTeamNum") return e.team
		if (n == "m_iScore") return SCORE[e.team]
		return 0
	}
}
::Convars <- { GetInt = function(n) { return n == "mp_maxrounds" ? 4 : (n.find("bot_allow") == 0 ? 1 : 0) },
	GetStr = function(n) { return "always" } }
::SendToServerConsole <- function(c) { print("   SERVERCMD " + c + "\n") }
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
	local o = ""
	foreach (i, c in s) { if (c == 7) { o += "<"; } else if (c == 1) o += ">"; else if (c >= 32 || c < 0) o += c.tochar() }
	print("   CHAT[" + p.name + "] " + o + "\n")
}
::EV <- {}
::__CollectGameEventCallbacks <- function(scope) { foreach (k, v in scope) EV[k.slice(12)] <- v }
dofile(DIR + "/mapspawn.nut")
// think вызывается так, как попросил скрипт (return = через сколько секунд)
::run <- function(sec) { local end = NOW + sec; while (NOW < end) { NOW += 0.05; if (THINK && NOW >= NEXT - 0.001) { THINKS++; NEXT = NOW + THINK() } } }
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
