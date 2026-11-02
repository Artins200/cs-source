#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ToxicBots — голос. Слушает микрофон, распознаёт русскую речь оффлайн (Vosk)
и передаёт текст в игру через cstrike/scriptdata/toxicbots_voice.txt.
Боты отвечают на сказанное так же, как на чат.

  python toxic_voice.py                 зажимаешь K (как войс в CS:S) и говоришь
  python toxic_voice.py --mode always   слушает всегда
  python toxic_voice.py --key v         другая клавиша
  python toxic_voice.py --big           большая модель (точнее, ~1.8 ГБ)
  python toxic_voice.py --no-mic        только озвучка ботов, без микрофона
  python toxic_voice.py --no-tts        только микрофон, боты без голоса
  python toxic_voice.py --demo          прослушать все голоса ботов
"""
import argparse
import json
import os
import queue
import sys
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = {
    'small': 'vosk-model-small-ru-0.22',
    'big': 'vosk-model-ru-0.42',
}
EPOCH = 1735689600  # 2025-01-01: порядковые номера влезают в int32


def find_cstrike(arg):
    if arg:
        return arg
    p = HERE
    for _ in range(6):
        p = os.path.dirname(p)
        if os.path.basename(p).lower() == 'cstrike' or os.path.isfile(os.path.join(p, 'gameinfo.txt')):
            return p
    sys.exit('Не нашёл папку cstrike. Положи мод в cstrike/custom/toxicbots или укажи --game "путь/к/cstrike"')


def ensure_model(name):
    mdir = os.path.join(HERE, 'model', name)
    if os.path.isdir(mdir):
        return mdir
    os.makedirs(os.path.join(HERE, 'model'), exist_ok=True)
    url = 'https://alphacephei.com/vosk/models/%s.zip' % name
    zpath = os.path.join(HERE, 'model', name + '.zip')
    print('Качаю модель распознавания речи (один раз):', url)

    def hook(n, bs, total):
        if total > 0:
            sys.stdout.write('\r  %d%%' % min(100, n * bs * 100 // total))
            sys.stdout.flush()
    urllib.request.urlretrieve(url, zpath, hook)
    print('\nРаспаковываю...')
    with zipfile.ZipFile(zpath) as z:
        z.extractall(os.path.join(HERE, 'model'))
    os.remove(zpath)
    return mdir


class Outbox:
    """Пишет фразы в файл, который читает скрипт игры. Хранит последние 20 строк."""

    def __init__(self, path):
        self.path = path
        self.lines = []
        self.seq = int((time.time() - EPOCH) * 10)
        os.makedirs(os.path.dirname(path), exist_ok=True)

    def send(self, text):
        self.seq = max(self.seq + 1, int((time.time() - EPOCH) * 10))
        self.lines = (self.lines + ['%d\t%s' % (self.seq, text.replace('\t', ' '))])[-20:]
        data = ('\n'.join(self.lines) + '\n').encode('utf-8')
        tmp = self.path + '.tmp'
        for _ in range(20):
            try:
                with open(tmp, 'wb') as f:
                    f.write(data)
                os.replace(tmp, self.path)
                return
            except OSError:
                time.sleep(0.05)
        print('  ! не смог записать', self.path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mode', choices=['ptt', 'always'], default='ptt')
    ap.add_argument('--key', default='k', help='клавиша push-to-talk (по умолчанию k, как в CS:S)')
    ap.add_argument('--big', action='store_true', help='большая модель Vosk')
    ap.add_argument('--game', help='путь к папке cstrike')
    ap.add_argument('--device', type=int, default=None, help='номер микрофона (см. --list)')
    ap.add_argument('--list', action='store_true', help='список микрофонов')
    ap.add_argument('--no-mic', action='store_true', help='не слушать микрофон')
    ap.add_argument('--no-tts', action='store_true', help='не озвучивать ботов')
    ap.add_argument('--tts-volume', type=float, default=1.0)
    ap.add_argument('--voices', help='только эти модели, напр. dmitri,ruslan')
    ap.add_argument('--demo', action='store_true', help='прослушать все голоса')
    a = ap.parse_args()

    import sounddevice as sd
    if a.list:
        print(sd.query_devices())
        return
    if a.demo:
        import toxic_tts
        toxic_tts.demo(HERE)
        return
    cs = find_cstrike(a.game)
    speaker = None
    if not a.no_tts:
        try:
            import toxic_tts
            speaker = toxic_tts.Speaker(HERE, cs, a.tts_volume, a.voices.split(',') if a.voices else None)
            speaker.run()
            print('Озвучка ботов включена. Голоса:', ', '.join(p[0] for p in speaker.presets))
        except Exception as e:
            print('Озвучка недоступна:', e)
    if a.no_mic:
        print('Микрофон выключен (--no-mic). Ctrl+C — выход.')
        while True:
            time.sleep(1)
    from vosk import Model, KaldiRecognizer, SetLogLevel
    SetLogLevel(-1)
    out = Outbox(os.path.join(cs, 'scriptdata', 'toxicbots_voice.txt'))
    model = Model(ensure_model(MODELS['big' if a.big else 'small']))
    rate = 16000
    rec = KaldiRecognizer(model, rate)
    audio = queue.Queue()

    held = {'on': a.mode == 'always', 'flush': False}
    if a.mode == 'ptt':
        try:
            from pynput import keyboard

            def match(k):
                return getattr(k, 'char', None) in (a.key, a.key.upper()) or str(k) == 'Key.' + a.key

            def press(k):
                if match(k) and not held['on']:
                    held['on'] = True

            def release(k):
                if match(k) and held['on']:
                    held['on'] = False
                    held['flush'] = True
            keyboard.Listener(on_press=press, on_release=release, daemon=True).start()
        except Exception as e:  # нет pynput / нет прав
            print('Push-to-talk недоступен (%s), слушаю всегда.' % e)
            held['on'] = True

    def cb(data, frames, t, status):
        if held['on'] and not (speaker and speaker.busy.is_set()):
            audio.put(bytes(data))

    def emit(res):
        text = json.loads(res).get('text', '').strip()
        if text:
            print('  >>', text)
            out.send(text)

    print('ToxicBots голос запущен. Игра:', cs)
    print('Режим:', 'зажми "%s" и говори' % a.key.upper() if a.mode == 'ptt' else 'слушаю всегда', '| Ctrl+C — выход')
    with sd.RawInputStream(samplerate=rate, blocksize=4000, dtype='int16', channels=1,
                           device=a.device, callback=cb):
        while True:
            try:
                data = audio.get(timeout=0.1)
                if rec.AcceptWaveform(data):
                    emit(rec.Result())
            except queue.Empty:
                pass
            if held['flush'] and audio.empty():
                held['flush'] = False
                emit(rec.FinalResult())


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
