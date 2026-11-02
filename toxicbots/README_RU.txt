ToxicBots для Counter-Strike: Source
====================================
1) Эта папка (toxicbots) должна лежать тут:
   ...\steamapps\common\Counter-Strike Source\cstrike\custom\toxicbots\
   (внутри должно быть scripts\vscripts\mapspawn.nut)
2) Steam -> Counter-Strike: Source -> Свойства -> Параметры запуска:
      -novid +exec toxicbots
   (SourceMod и -insecure НЕ нужны)
3) Создай сервер с ботами, пиши в чат — боты отвечают.
   В консоли должно быть: [ToxicBots] загружен ...
4) Голос: запусти voice\ЗАПУСТИТЬ_ГОЛОС.bat и не закрывай. Зажимай K и говори —
   боты ответят в чат и ГОЛОСОМ (у каждого бота свой). --demo — послушать голоса.
   10 фраз ("бляя проебали раунд" и т.д.) звучат прямо из игры и без программы.

Команды в чате: !tb on | !tb off | !tb stat | !tb debug
Настройки (шансы, скорость ответов): scripts\vscripts\toxicbots\config.nut
