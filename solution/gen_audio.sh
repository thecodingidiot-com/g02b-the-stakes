#!/bin/bash
# Synthesize every sound g02b needs -- own-work, generated from square
# waves with Python's stdlib `wave` module, the same procedurally-
# generated-art spirit as gen_assets.sh's PIL rectangles. g01c sourced
# real royalty-free tracks from Freesound because that was the right
# call for a quiz game's mood music; these are simple 8-bit sound
# effects, cheap and fast to synthesize instead -- zero licensing
# surface, matching this game's whole procedurally-generated look.
#
# assets/sfx_jump.wav     -- short rising beep
# assets/sfx_land.wav     -- short low thud
# assets/sfx_collect.wav  -- two-note rising chime
# assets/sfx_death.wav    -- descending sweep
# assets/sfx_win.wav      -- three-note ascending fanfare
# assets/music.wav        -- a short looping bassline

set -e

mkdir -p assets

python3 - <<'EOF'
import math
import struct
import wave

RATE = 44100

def square_wave(freq, duration, amplitude=0.3, fade=0.01):
    n = int(RATE * duration)
    fade_n = int(RATE * fade)
    samples = []
    for i in range(n):
        t = i / RATE
        s = amplitude if math.sin(2 * math.pi * freq * t) >= 0 else -amplitude
        if i < fade_n:
            s *= i / fade_n
        elif i > n - fade_n:
            s *= (n - i) / fade_n
        samples.append(s)
    return samples

def sweep_wave(freq_start, freq_end, duration, amplitude=0.3, fade=0.01):
    n = int(RATE * duration)
    fade_n = int(RATE * fade)
    samples = []
    phase = 0.0
    for i in range(n):
        frac = i / n
        freq = freq_start + (freq_end - freq_start) * frac
        phase += freq / RATE
        s = amplitude if math.sin(2 * math.pi * phase) >= 0 else -amplitude
        if i < fade_n:
            s *= i / fade_n
        elif i > n - fade_n:
            s *= (n - i) / fade_n
        samples.append(s)
    return samples

def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out

def write_wav(path, samples):
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        f.writeframes(frames)
    print(f"  wrote {path}")

write_wav("assets/sfx_jump.wav", sweep_wave(300, 600, 0.10))
write_wav("assets/sfx_land.wav", square_wave(140, 0.08))
write_wav("assets/sfx_collect.wav", concat(
    square_wave(523, 0.08),
    square_wave(784, 0.10),
))
write_wav("assets/sfx_death.wav", sweep_wave(400, 90, 0.40))
write_wav("assets/sfx_win.wav", concat(
    square_wave(523, 0.12),
    square_wave(659, 0.12),
    square_wave(784, 0.18),
))

# A short 4-bar bassline, looped by Mix_PlayMusic's own loop count --
# the file itself is just one pass.
NOTES = [220, 220, 261, 196, 220, 220, 293, 261]
bass = concat(*(square_wave(f, 0.28, amplitude=0.18, fade=0.02) for f in NOTES))
write_wav("assets/music.wav", bass)
EOF
