import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parents[1] / "godot-project" / "audio"
ROOT.mkdir(parents=True, exist_ok=True)


def render(name, duration, notes, noise=0.0, loop=False):
    samples = [0.0] * round(duration * RATE)
    rng = random.Random(170300)
    for start, frequency, length, gain in notes:
        begin = round(start * RATE)
        count = min(round(length * RATE), len(samples) - begin)
        for index in range(count):
            seconds = index / RATE
            attack = min(1.0, seconds / 0.007)
            release = min(1.0, (count - 1 - index) / (RATE * 0.035))
            decay = math.exp(-seconds * (5.0 if loop else 12.0))
            phase = math.tau * frequency * seconds
            tone = math.sin(phase) + 0.24 * math.sin(phase * 2.0) + 0.08 * math.sin(phase * 3.0)
            transient = noise * rng.uniform(-1, 1) * math.exp(-seconds * 100)
            samples[begin + index] += (tone + transient) * attack * release * decay * gain
    peak = max(abs(sample) for sample in samples) or 1.0
    ceiling = 0.55 if loop else 0.72
    factor = min(1.0, ceiling / peak)
    samples[0] = samples[-1] = 0.0
    with wave.open(str(ROOT / (name + ".wav")), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", round(sample * factor * 32767)) for sample in samples))


render("launch", 0.13, [(0, 330, 0.13, 0.30), (0.018, 660, 0.10, 0.10)], noise=0.06)
for index, frequency in enumerate([523.251, 587.330, 659.255, 783.991, 880.000]):
    render("collect_" + str(index), 0.22, [(0, frequency, 0.22, 0.35), (0.025, frequency * 2, 0.16, 0.07)])
render("car_complete", 0.48, [(0, 523.251, 0.30, 0.26), (0.075, 659.255, 0.30, 0.25), (0.15, 783.991, 0.33, 0.28)])
render("level_clear", 0.84, [(0, 523.251, 0.30, 0.22), (0.10, 659.255, 0.34, 0.22), (0.20, 783.991, 0.40, 0.24), (0.34, 1046.502, 0.50, 0.28), (0.34, 523.251, 0.50, 0.12)])
render("deadlock", 0.30, [(0, 261.626, 0.22, 0.22), (0.10, 220, 0.20, 0.18)])
render("button", 0.09, [(0, 740, 0.09, 0.18)], noise=0.03)
render("undo", 0.24, [(0, 659.255, 0.16, 0.20), (0.07, 523.251, 0.17, 0.20)])
notes = []
for beat in range(32):
    chord = [[261.626, 329.628, 391.995], [220, 261.626, 329.628], [174.614, 220, 261.626], [195.998, 246.942, 293.665]][beat // 8]
    notes.append((beat * 0.5, chord[beat % 3], 1.4, 0.10))
    if beat % 4 == 0:
        notes.append((beat * 0.5, chord[0] / 2, 1.8, 0.09))
render("music_loop", 16.0, notes, loop=True)
print("Built 12 original audio files; mono 44.1kHz PCM; deterministic seed; no third-party assets")
