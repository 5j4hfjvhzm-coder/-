"""Generate narration (Kokoro TTS, American English) with word timestamps."""
import json, sys
import numpy as np, soundfile as sf
from kokoro_onnx import Kokoro

TTS = sys.argv[1]  # dir with kokoro-v1.0.onnx (duration-export) + voices-v1.0.bin
OUT = sys.argv[2]
VOICE, SPEED, SR = "af_heart", 1.05, 24000
LINES = [  # (start seconds, spoken text, display words)
    (0.25, "Did you know your brain can stop you from tickling yourself?",
     "Did you know your brain can stop you from tickling yourself?"),
    (3.20, "That's because your brain predicts the sensations caused by your own movements.",
     "That's because your brain predicts the sensations caused by your own movements."),
    (9.15, "Your cerebellum helps predict those sensations, so the touch feels less surprising.",
     "Your cerebellum helps predict those sensations, so the touch feels less surprising."),
    (15.70, "But when someone else tickles you, your brain can't predict it as easily!",
     "But when someone else tickles you, your brain can't predict it as easily!"),
    (21.90, "Follow Human dot E X E, for more mind-blowing body facts.",
     "Follow Human.exe for more mind-blowing body facts."),
]
k = Kokoro(f"{TTS}/kokoro-v1.0.onnx", f"{TTS}/voices-v1.0.bin")
total = np.zeros(int(28.0 * SR), np.float32)
words_out = []
for li, (t0, spoken, display) in enumerate(LINES):
    audio, sr, tim = k.create_timed(spoken, VOICE, SPEED, "en-us")
    assert sr == SR
    # group phonemes into spoken words
    groups, cur = [], []
    for t in tim:
        if t.phoneme == " ":
            if cur: groups.append(cur); cur = []
        elif t.phoneme in ",.!?;:—…\"'":
            continue
        else:
            cur.append(t)
    if cur: groups.append(cur)
    spans = [(g[0].start, g[-1].end) for g in groups]
    dw = display.split()
    if li == 4:  # 'Human dot E X E' (5 spoken) -> 'Human.exe' (1 display)
        spans = spans[:1] + [(spans[1][0], spans[5][1])] + spans[6:]
    assert len(spans) == len(dw), (li, len(spans), len(dw), [ ''.join(x.phoneme for x in g) for g in groups])
    for w, (a, b) in zip(dw, spans):
        words_out.append({"line": li, "word": w, "start": round(t0 + a, 3), "end": round(t0 + b, 3)})
    i0 = int(t0 * SR)
    total[i0:i0 + len(audio)] += audio
    print(li, f"{t0:.2f} -> {t0 + len(audio) / SR:.2f}")
sf.write(f"{OUT}/narration.wav", total, SR)
json.dump(words_out, open(f"{OUT}/words.json", "w"), indent=1)
