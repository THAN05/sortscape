"""Generate SortScape's original short PCM chimes; no external samples."""
from pathlib import Path
import math
import struct
import wave

output = Path(__file__).resolve().parents[1] / "Sources/SortScape/Resources"
output.mkdir(parents=True, exist_ok=True)
for name, notes in [
    ("move", [(660, .075), (880, .10)]),
    ("invalid", [(180, .09), (140, .10)]),
    ("complete", [(523.25, .12), (659.25, .12), (783.99, .12), (1046.5, .3)]),
]:
    samples = []
    for frequency, duration in notes:
        count = int(44100 * duration)
        for index in range(count):
            time = index / 44100
            envelope = min(1, index / 220) * max(0, 1 - index / count) ** 1.8
            value = (math.sin(2 * math.pi * frequency * time) + .2 * math.sin(2 * math.pi * frequency * 2 * time)) * .28 * envelope
            samples.append(struct.pack("<h", int(value * 32767)))
    with wave.open(str(output / (name + ".wav")), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(44100)
        audio.writeframes(b"".join(samples))
