"""いたちごっこ：BGM と SE を numpy だけで合成して audio/*.wav に書き出す。

    python tools/gen_audio.py
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


# ------------------------------------------------------------ 基本部品
def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(f"{name:10s} {len(x) / SR:5.1f}s")


def T(dur):
    return np.arange(int(SR * dur)) / SR


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def osc(freq, dur, wave_="sine"):
    f = freq if np.ndim(freq) else np.full(int(SR * dur), float(freq))
    ph = np.cumsum(f) / SR
    if wave_ == "sine":
        return np.sin(2 * np.pi * ph)
    if wave_ == "square":
        return np.sign(np.sin(2 * np.pi * ph))
    if wave_ == "saw":
        return 2 * (ph % 1.0) - 1
    if wave_ == "tri":
        return 2 * np.abs(2 * (ph % 1.0) - 1) - 1
    raise ValueError(wave_)


def adsr(n, a=0.005, d=0.0, s=1.0, r=0.02):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if r and nr and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def decay(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def lowpass(x, fc):
    a = 1 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x, fc):
    return x - lowpass(x, fc)


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def pad(x, n):
    y = np.zeros(n)
    y[: min(n, len(x))] = x[:n]
    return y


def mix_at(dst, src, t0, gain=1.0):
    i = int(t0 * SR)
    if i >= len(dst):
        return
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i] * gain


def silence(dur):
    return np.zeros(int(SR * dur))


# ------------------------------------------------------------ SE
def se_pop():  # 吹き出し
    d = 0.09
    f = np.linspace(520, 880, int(SR * d))
    return osc(f, d, "sine") * decay(len(f), 0.05)


def se_yosh():  # よし！
    out = silence(0.5)
    for i, m in enumerate([72, 76, 79, 84]):
        n = osc(mtof(m), 0.18, "square") * 0.5 + osc(mtof(m) * 2, 0.18, "sine") * 0.3
        mix_at(out, n * decay(len(n), 0.09), i * 0.07)
    return out


def se_drill():  # ガガガッ
    d = 1.2
    t = T(d)
    f = 90 + 20 * np.sin(2 * np.pi * 14 * t)
    x = osc(f, d, "saw") * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 14 * t)))
    x += highpass(noise(d), 800) * 0.35
    return lowpass(x, 2500) * adsr(len(x), 0.01, r=0.1)


def se_hammer():  # カンカンカン
    out = silence(1.3)
    for i in range(5):
        n = osc(1400 + rng.random() * 200, 0.2, "sine") * 0.6 + highpass(noise(0.2), 2000) * 0.4
        mix_at(out, n * decay(len(n), 0.03), i * 0.24)
    return out


def se_thud():  # ドスッ / ガシャン
    d = 0.5
    f = np.linspace(160, 40, int(SR * d))
    x = osc(f, d, "sine") * decay(len(f), 0.12)
    x += lowpass(noise(d), 1800) * decay(len(f), 0.05) * 0.8
    x += highpass(noise(d), 3000) * decay(len(f), 0.03) * 0.3
    return x


def se_dig():  # ザクザク
    out = silence(1.0)
    for i in range(5):
        n = lowpass(noise(0.14), 3500) * decay(int(SR * 0.14), 0.045)
        mix_at(out, n, i * 0.2)
    return out


def se_knock():  # コンコン
    out = silence(0.5)
    for i in range(2):
        n = osc(260, 0.14, "sine") * decay(int(SR * 0.14), 0.03) + lowpass(noise(0.14), 900) * decay(int(SR * 0.14), 0.02) * 0.5
        mix_at(out, n, i * 0.2)
    return out


def se_boing():  # ひょい
    d = 0.35
    t = T(d)
    f = 300 + 500 * np.sin(np.pi * t / d) + 40 * np.sin(2 * np.pi * 30 * t)
    return osc(f, d, "sine") * decay(len(t), 0.25)


def se_get():  # ゲット！
    out = silence(0.7)
    for i, m in enumerate([67, 72, 76, 79]):
        n = osc(mtof(m), 0.3, "tri") * decay(int(SR * 0.3), 0.14)
        mix_at(out, n, i * 0.09)
    return out


def se_shock():  # ぐぬぬ（ワウワウワ～）
    out = silence(1.2)
    for i, (m, dur) in enumerate([(62, 0.25), (60, 0.25), (58, 0.25), (55, 0.55)]):
        t = T(dur)
        vib = 1 + 0.02 * np.sin(2 * np.pi * 6 * t) * (i == 3)
        x = osc(mtof(m) * vib, dur, "saw")
        x = lowpass(x, 1100)
        mix_at(out, x * adsr(len(x), 0.02, r=0.06) * 0.8, [0, 0.27, 0.54, 0.81][i])
    return out


def se_fanfare():  # ジャーン
    d = 1.4
    x = np.zeros(int(SR * d))
    for m in [60, 64, 67, 72]:
        x += osc(mtof(m), d, "saw") * 0.3 + osc(mtof(m) * 2, d, "square") * 0.1
    x = lowpass(x, 2800)
    x += highpass(noise(d), 4000) * decay(len(x), 0.05) * 0.4
    return x * decay(len(x), 0.6)


def se_siren():  # ウーーーッ
    d = 1.6
    t = T(d)
    f = 700 + 300 * np.sin(2 * np.pi * 1.3 * t)
    return lowpass(osc(f, d, "saw"), 3000) * adsr(len(t), 0.05, r=0.2)


def se_beep():  # ピコーン
    out = silence(0.35)
    for i, f in enumerate([1200, 1800]):
        n = osc(f, 0.12, "square") * adsr(int(SR * 0.12), 0.003, r=0.03) * 0.5
        mix_at(out, n, i * 0.1)
    return out


def se_whoosh():  # スーッ
    d = 1.2
    x = lowpass(noise(d), 1500)
    x = highpass(x, 200)
    return x * np.sin(np.pi * T(d) / d) ** 2


def se_rumble():  # ドドドド
    d = 1.6
    t = T(d)
    x = lowpass(noise(d), 160) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
    x += osc(48 + 6 * np.sin(2 * np.pi * 3 * t), d, "sine") * 0.8
    return x * adsr(len(t), 0.1, r=0.3)


def se_splash():  # ザバーン
    d = 0.9
    x = bandish(noise(d), 600, 4500) * decay(int(SR * d), 0.25)
    return x


def bandish(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def se_bark():  # ワンワン
    out = silence(0.7)
    for i in range(2):
        d = 0.18
        f = np.linspace(420, 260, int(SR * d))
        x = osc(f, d, "saw") * 0.8 + bandish(noise(d), 500, 2500) * 0.3
        x = lowpass(x, 1800) * decay(len(f), 0.09)
        mix_at(out, x, i * 0.28)
    return out


def se_chime():  # きらん / ふわぁ等の小音
    out = silence(0.5)
    for i, m in enumerate([88, 93]):
        n = osc(mtof(m), 0.3, "sine") * decay(int(SR * 0.3), 0.12)
        mix_at(out, n, i * 0.08)
    return out


def se_munch():  # もぐもぐ・なでなで
    out = silence(0.8)
    for i in range(4):
        n = lowpass(noise(0.1), 900) * decay(int(SR * 0.1), 0.035)
        mix_at(out, n, i * 0.18)
    return out


def se_squeak():  # ギギギ・ウィーン
    d = 1.0
    t = T(d)
    f = 400 + 250 * t / d + 15 * np.sin(2 * np.pi * 25 * t)
    return lowpass(osc(f, d, "saw"), 2000) * adsr(len(t), 0.05, r=0.15) * 0.7


def se_snip():  # パチン
    out = silence(1.0)
    for i in range(4):
        n = highpass(noise(0.08), 3000) * decay(int(SR * 0.08), 0.015) + osc(2200, 0.08, "sine") * decay(int(SR * 0.08), 0.02) * 0.4
        mix_at(out, n, i * 0.25)
    return out


def se_salute():  # ビシッ
    d = 0.2
    return (highpass(noise(d), 1500) * 0.7 + osc(900, d, "square") * 0.2) * decay(int(SR * d), 0.03)


def se_end():  # エンディングの一撃
    d = 3.5
    x = np.zeros(int(SR * d))
    for f, g in [(65.4, 1.0), (98.0, 0.5), (130.8 * 1.0, 0.3)]:
        x += osc(f, d, "sine") * g
    x += osc(880, d, "sine") * decay(len(x), 1.0) * 0.12 + osc(1327, d, "sine") * decay(len(x), 0.7) * 0.08
    return x * adsr(len(x), 0.01, r=1.0) * decay(len(x), 1.8)


def se_step():  # ぺたぺた
    d = 0.1
    return lowpass(noise(d), 700) * decay(int(SR * d), 0.03)


def se_wind():  # 静寂の風
    d = 2.8
    t = T(d)
    x = bandish(noise(d), 200, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.4 * t - 1.2))
    return x * adsr(len(x), 0.4, r=0.6) * 0.4


# ------------------------------------------------------------ BGM
def pluck(m, dur, vol=1.0, wave_="tri", tau=0.12):
    x = osc(mtof(m), dur, wave_)
    return x * decay(len(x), tau) * vol


def kick(vol=1.0):
    d = 0.18
    f = np.linspace(150, 45, int(SR * d))
    return osc(f, d, "sine") * decay(len(f), 0.06) * vol


def hat(vol=0.3):
    return highpass(noise(0.05), 6000) * decay(int(SR * 0.05), 0.012) * vol


def snare(vol=0.5):
    d = 0.14
    return (bandish(noise(d), 1200, 6000) * 0.8 + osc(190, d, "sine") * 0.4) * decay(int(SR * d), 0.04) * vol


CH = {  # コード: (ルート, 3度, 5度) MIDI
    "C": (48, 52, 55), "Am": (45, 48, 52), "F": (41, 45, 48), "G": (43, 47, 50),
    "Dm": (50, 53, 57), "Em": (40, 43, 47), "G7": (43, 47, 53),
}


def bgm_main():
    bpm = 132
    beat = 60 / bpm
    prog_a = ["C", "Am", "F", "G", "C", "Am", "Dm", "G7"]
    prog_b = ["Am", "Dm", "G", "C", "F", "G", "C", "C"]
    # メロディ(8分音符x8/小節, 0=休符)
    mel_a = [
        [76, 0, 72, 76, 79, 0, 76, 72], [76, 0, 72, 69, 72, 0, 0, 0],
        [77, 0, 74, 77, 81, 0, 77, 74], [74, 0, 71, 74, 79, 0, 0, 0],
        [76, 0, 72, 76, 79, 81, 79, 76], [72, 0, 69, 72, 76, 0, 72, 69],
        [74, 77, 74, 77, 81, 0, 77, 74], [71, 74, 77, 74, 71, 0, 0, 0],
    ]
    mel_b = [
        [81, 0, 79, 76, 72, 76, 79, 0], [77, 0, 74, 77, 81, 0, 77, 0],
        [79, 0, 76, 79, 83, 0, 79, 74], [76, 0, 72, 76, 79, 0, 0, 0],
        [77, 0, 81, 77, 74, 77, 81, 0], [79, 0, 83, 79, 74, 79, 83, 0],
        [84, 0, 79, 76, 72, 76, 79, 76], [72, 0, 0, 0, 0, 0, 0, 0],
    ]
    bars = 16
    out = silence(bars * 4 * beat)
    for b in range(bars):
        prog = prog_a if b < 8 else prog_b
        mel = mel_a if b < 8 else mel_b
        ch = CH[prog[b % 8]]
        t0 = b * 4 * beat
        # ベース: oom-pah
        for k, note in enumerate([ch[0], ch[2] - 12 + 12, ch[0] + 0, ch[2]]):
            if k in (0, 2):
                mix_at(out, pluck(note, beat * 0.9, 0.9, "tri", 0.2), t0 + k * beat)
            else:
                for n in ch:
                    mix_at(out, pluck(n + 12, beat * 0.5, 0.16, "square", 0.06), t0 + k * beat)
        # リズム
        mix_at(out, kick(0.8), t0)
        mix_at(out, kick(0.7), t0 + 2 * beat)
        for k in range(8):
            mix_at(out, hat(0.25 if k % 2 else 0.12), t0 + k * beat / 2)
        mix_at(out, snare(0.35), t0 + beat)
        mix_at(out, snare(0.35), t0 + 3 * beat)
        # メロディ
        for k, m in enumerate(mel[b % 8]):
            if m:
                mix_at(out, pluck(m, beat * 0.6, 0.6, "tri", 0.1) + pluck(m + 12, beat * 0.6, 0.12, "sine", 0.08), t0 + k * beat / 2)
    return out


def bgm_open():
    d = 24.0
    t = T(d)
    x = np.zeros(len(t))
    for f, g in [(36.7, 1.0), (55.0, 0.6), (73.4, 0.3)]:
        x += osc(f * (1 + 0.002 * np.sin(2 * np.pi * 0.2 * t)), d, "saw") * g * 0.25
    x = lowpass(x, 400) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t))
    x += osc(146.8, d, "sine") * 0.08
    # 重い鐘
    for k in range(6):
        t0 = 1.0 + k * 4.0
        n = np.zeros(int(SR * 3.5))
        for ratio, g in [(1, 1), (2.76, 0.5), (5.4, 0.3)]:
            n += osc(110 * ratio, 3.5, "sine") * g
        mix_at(x, n * decay(len(n), 1.2) * 0.35, t0)
    return x * adsr(len(x), 1.0, r=0.0)


def bgm_final():
    bpm = 120
    beat = 60 / bpm
    bars = 4
    out = silence(bars * 4 * beat)
    prog = ["Em", "Em", "Am", "G"]
    for b in range(bars):
        t0 = b * 4 * beat
        ch = CH[prog[b]]
        for k in range(8):
            mix_at(out, pluck(ch[0], beat * 0.4, 0.8, "saw", 0.1), t0 + k * beat / 2)
        arp = [ch[0] + 24, ch[1] + 24, ch[2] + 24, ch[1] + 24]
        for k in range(16):
            mix_at(out, pluck(arp[k % 4], beat * 0.3, 0.35, "square", 0.05), t0 + k * beat / 4)
        mix_at(out, kick(0.9), t0)
        mix_at(out, kick(0.9), t0 + 2 * beat)
        for k in range(8):
            mix_at(out, snare(0.12 + 0.03 * b), t0 + 2 * beat + k * beat / 4 * 1.0 if b == 3 else t0 + 3 * beat)
    return lowpass(out, 6000)


def main():
    se = {
        "pop": se_pop, "yosh": se_yosh, "drill": se_drill, "hammer": se_hammer, "thud": se_thud,
        "dig": se_dig, "knock": se_knock, "boing": se_boing, "get": se_get, "shock": se_shock,
        "fanfare": se_fanfare, "siren": se_siren, "beep": se_beep, "whoosh": se_whoosh,
        "rumble": se_rumble, "splash": se_splash, "bark": se_bark, "chime": se_chime,
        "munch": se_munch, "squeak": se_squeak, "snip": se_snip, "salute": se_salute,
        "end": se_end, "wind": se_wind,
    }
    for k, f in se.items():
        save("se_" + k, f())
    save("bgm_main", bgm_main(), 0.7)
    save("bgm_open", bgm_open(), 0.7)
    save("bgm_final", bgm_final(), 0.7)


if __name__ == "__main__":
    main()
