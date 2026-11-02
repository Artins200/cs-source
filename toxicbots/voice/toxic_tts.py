# -*- coding: utf-8 -*-
"""
ToxicBots — живая озвучка ответов ботов (оффлайн, Piper TTS).
Игра пишет фразы ботов в cstrike/scriptdata/toxicbots_tts.txt, этот модуль
читает их и проговаривает. Каждому боту — свой голос из пресетов ниже.
"""
import os
import queue
import threading
import time
import urllib.request

HF = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/%s/medium/ru_RU-%s-medium.onnx'
MODELS = ['denis', 'dmitri', 'irina', 'ruslan']

# Пресеты голосов: модель, темп (length_scale: >1 медленнее), высота (rate: <1 ниже/басом)
PRESETS = [
    ('Гопник-бас',         'dmitri', 1.05, 0.86),
    ('Дерзкий школьник',   'ruslan', 0.90, 1.14),
    ('Спокойный токсик',   'denis',  1.00, 1.00),
    ('Стерва',             'irina',  0.95, 1.00),
    ('Пьяный дед',         'denis',  1.30, 0.90),
    ('Писклявый',          'irina',  0.90, 1.22),
    ('Тильтер-тараторка',  'ruslan', 0.75, 1.03),
    ('Злой робот',         'dmitri', 0.85, 0.95),
]


def ensure_voice(base, name):
    d = os.path.join(base, 'tts')
    os.makedirs(d, exist_ok=True)
    onnx = os.path.join(d, 'ru_RU-%s-medium.onnx' % name)
    for path, url in ((onnx, HF % (name, name)), (onnx + '.json', HF % (name, name) + '.json')):
        if not os.path.isfile(path):
            print('Качаю голос %s: %s' % (name, os.path.basename(path)))
            urllib.request.urlretrieve(url, path + '.part')
            os.replace(path + '.part', path)
    return onnx


def load_voice(path, threads):
    """Голос Piper с ограничением потоков процессора (чтобы не отнимать CPU у игры)."""
    import json
    import onnxruntime
    from piper import PiperVoice
    try:
        from piper.config import PiperConfig
        so = onnxruntime.SessionOptions()
        so.intra_op_num_threads = max(1, threads)
        so.inter_op_num_threads = 1
        so.execution_mode = onnxruntime.ExecutionMode.ORT_SEQUENTIAL
        with open(path + '.json', encoding='utf-8') as f:
            cfg = PiperConfig.from_dict(json.load(f))
        sess = onnxruntime.InferenceSession(path, sess_options=so, providers=['CPUExecutionProvider'])
        return PiperVoice(config=cfg, session=sess)
    except Exception as e:  # другая версия piper — грузим как есть
        print('  (голос без ограничения потоков: %s)' % e)
        return PiperVoice.load(path)


class Speaker:
    def __init__(self, base, cstrike, volume=1.0, only=None, threads=2, max_chars=0):
        from piper import PiperVoice  # noqa
        self.threads = threads
        self.max_chars = max_chars
        self.base = base
        self.path = os.path.join(cstrike, 'scriptdata', 'toxicbots_tts.txt')
        self.volume = volume
        self.voices = {}
        self.presets = [p for p in PRESETS if only is None or p[1] in only] or PRESETS
        self.q = queue.Queue()
        self.busy = threading.Event()   # пока бот говорит — микрофон игнорируется
        self.session, self.last, self.inited = None, 0, False

    def voice(self, model):
        if model not in self.voices:
            self.voices[model] = load_voice(ensure_voice(self.base, model), self.threads)
        return self.voices[model]

    def preset_for(self, botidx):
        return self.presets[botidx % len(self.presets)]

    def say(self, botidx, text):
        import numpy as np
        import sounddevice as sd
        from piper import SynthesisConfig
        name, model, length, rate = self.preset_for(botidx)
        if self.max_chars and len(text) > self.max_chars:   # лёгкий режим: длинное режем по фразе
            cut = max(text.rfind('.', 0, self.max_chars), text.rfind('!', 0, self.max_chars), text.rfind('?', 0, self.max_chars))
            text = text[:cut + 1] if cut > 20 else text[:self.max_chars]
        v = self.voice(model)
        cfg = SynthesisConfig(length_scale=length, volume=self.volume)
        audio = [c.audio_int16_array for c in v.synthesize(text, syn_config=cfg)]
        if not audio:
            return
        pcm = np.concatenate(audio)
        self.busy.set()
        try:
            sd.play(pcm, samplerate=int(v.config.sample_rate * rate))
            sd.wait()
        finally:
            time.sleep(0.2)
            self.busy.clear()

    def poll(self):
        try:
            with open(self.path, 'rb') as f:
                raw = f.read().replace(b'\x00', b'').decode('utf-8', 'replace')
        except OSError:
            self.inited = True
            return
        for ln in raw.splitlines():
            parts = ln.split('\t', 3)
            if len(parts) < 4 or ':' not in parts[0]:
                continue
            sess, seq = parts[0].split(':', 1)
            try:
                seq, idx = int(seq), int(parts[1])
            except ValueError:
                continue
            if sess != self.session:          # новая карта = новая сессия
                self.session, self.last = sess, 0
            if seq <= self.last:
                continue
            self.last = seq
            if self.inited:
                self.q.put((idx, parts[3]))
        self.inited = True

    def preload(self):
        for m in sorted({p[1] for p in self.presets}):
            try:
                self.voice(m)
            except Exception as e:
                print('  ! голос %s: %s' % (m, e))

    def run(self):
        def worker():
            self.preload()                    # грузим голоса сразу, а не посреди раунда
            while True:
                idx, text = self.q.get()
                if self.q.qsize() > (1 if self.max_chars else 4):   # не копим отставание
                    continue
                try:
                    print('  бот #%d [%s]: %s' % (idx, self.preset_for(idx)[0], text))
                    self.say(idx, text)
                except Exception as e:
                    print('  ! озвучка:', e)
        threading.Thread(target=worker, daemon=True).start()

        def poller():
            while True:
                self.poll()
                time.sleep(0.2)
        threading.Thread(target=poller, daemon=True).start()


def demo(base, text='Бляя, проебали раунд. Кто вообще стрелял?'):
    """--demo: проговорить фразу всеми пресетами, чтобы выбрать любимые."""
    sp = Speaker(base, base)
    for i, p in enumerate(PRESETS):
        print('%d) %s' % (i, p[0]))
        sp.say(i, text)
