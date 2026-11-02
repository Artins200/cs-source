// Тест ядра в обычном интерпретаторе Squirrel 3 (без игры)
srand(time());
::RandomFloat <- function(a, b) { return a + (b - a) * rand() / RAND_MAX.tofloat() }
::RandomInt <- function(a, b) { return a + rand() % (b - a + 1) }
local dir = vargv[0]
dofile(dir + "/config.nut")
dofile(dir + "/data.nut")
dofile(dir + "/core.nut")
local phrases = ["ты еблан", "блять ты долбаёб конченый", "ты чё такой ДЕРЗКИЙ", "что за хуйня творится",
  "иди нахуй", "ты чё, тупой, объясни", "da", "nst t,kfy", "ty eblan", "мамку твою", "ты читер ебаный",
  "гг изи", "го б рашим", "бляя проебали катку", "лагает пиздец", "чё", "ты бот?", "абырвалг", "тебя чё ебёт",
  "ты еблааан", "e6лан", "х*й тебе"]
foreach (p in phrases) {
	local a = TBC.Analyze(p)
	local ctx = { name = "Игрок", bot = "Bot", kd = "3-11", k = 3, d = 11, map = "de_dust2", weapon = "AK-47",
		num = 2, perf = "ты 3-11", score = "3:9" }
	local r = TBC.Reply(a, "enemy", ctx)
	print(p + "  =>  [" + r[1] + " " + a.score + " w=" + a.word + "] " + r[0] + "\n")
}
