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
class FakeEnt {
	idx = 0; team = 0; bot = false; name = ""; alive = 1; scope = null; valid = true
	constructor(i, t, b, n) { idx = i; team = t; bot = b; name = n }
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
	GetPropInt = function(e, n) {
		if (n == "m_lifeState") return e.alive ? 0 : 2
		if (n == "m_iTeamNum") return e.team
		if (n == "m_iScore") return SCORE[e.team]
		return 0
	}
}
::Convars <- { GetInt = function(n) { return n == "mp_maxrounds" ? 4 : 0 } }
::TEAMS <- [FakeEnt(50, 2, false, "t"), FakeEnt(51, 3, false, "ct")]
::Entities <- { FindByClassname = function(prev, cls) {
	if (prev == null) return TEAMS[0]
	if (prev == TEAMS[0]) return TEAMS[1]
	return null } }
::THINK <- null
::SpawnEntityFromTable <- function(c, t) { return FakeEnt(60, 0, false, "think") }
::AddThinkToEnt <- function(e, f) { THINK = e.scope[f] }
::ClientPrint <- function(p, d, s) {
	local o = ""
	foreach (i, c in s) { if (c == 7) { o += "<"; } else if (c == 1) o += ">"; else if (c >= 32 || c < 0) o += c.tochar() }
	print("   CHAT[" + p.name + "] " + o + "\n")
}
::EV <- {}
::__CollectGameEventCallbacks <- function(scope) { foreach (k, v in scope) EV[k.slice(12)] <- v }
dofile(DIR + "/mapspawn.nut")
::run <- function(sec) { local end = NOW + sec; while (NOW < end) { NOW += 0.1; if (THINK) THINK() } }
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
