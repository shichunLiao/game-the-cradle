"""程序合成的占位配乐(2026-10-12,用户选「程序合成配乐」)。

    python3 tools/audio/make_music.py        # 写 assets/audio/music/{menu,outside,ending}.wav

三段都很淡,垫在环境声上面,不抢戏:
  menu     D 小调,i–VI–III–VII(Dm–B♭–F–C)慢慢铺底,一段四个音的「姐姐动机」(A–F–E–D),
           像远处的八音盒;
  outside  塔外:空旷的开放五度长音(D–A、C–G、B♭–F),偶尔几声很高很远的拨弦(D 多利亚);
  ending   同一段姐姐动机,换成 D 大调(A–F♯–E–D),最后落在 D 上 —— 「我找到了」。

每段 8 小节 × 4 拍,60 BPM = 32 秒,无缝循环:所有声部按「起点 + 本地时间」算相位,写进缓冲区时
下标对循环长度取模,跨过循环点的尾巴绕回开头;持续的低音把频率对齐到循环长度的整数圈。
单声道 22050Hz 16bit。以后换正式作曲:同名文件替换即可,游戏里的 `MusicPlayer` 不用改。

只用标准库(这台机器没有 numpy)。三段合计大约 20 秒。
"""
from __future__ import annotations

import array
import math
import pathlib
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets" / "audio" / "music"
SR = 22050
BEAT = 1.0                      # 60 BPM
BARS = 8
LOOP_S = BARS * 4 * BEAT        # 32 秒
N = int(LOOP_S * SR)
TAU = math.tau


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def loop_hz(f: float) -> float:
    """对齐到循环长度的整数圈(持续音用,循环点相位连续)。"""
    return round(f * LOOP_S) / LOOP_S


class Track:
    def __init__(self):
        self.pad = [0.0] * N
        self.lead = [0.0] * N

    def pad_note(self, midi, start_beat, beats, amp=0.07, attack=1.6, release=2.4):
        """铺底:正弦 + 微微失谐的第二个正弦 + 一点二次谐波,慢起慢收。"""
        f = hz(midi)
        start = int(start_beat * BEAT * SR)
        dur = beats * BEAT
        total = int((dur + release) * SR)
        for i in range(total):
            t = i / SR
            if t < attack:
                env = (t / attack) ** 2
            elif t < dur:
                env = 1.0
            else:
                env = max(0.0, 1.0 - (t - dur) / release) ** 2
            s = math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * 1.003 * t) + 0.12 * math.sin(TAU * 2 * f * t)
            self.pad[(start + i) % N] += s * env * amp

    def pluck(self, midi, start_beat, amp=0.16, decay=2.2, length=3.5):
        """八音盒一样的拨弦:基音 + 衰减更快的二、三次谐波。"""
        f = hz(midi)
        start = int(start_beat * BEAT * SR)
        total = int(length * SR)
        for i in range(total):
            t = i / SR
            env = (1.0 - math.exp(-t * 180.0)) * math.exp(-t * decay)
            s = (math.sin(TAU * f * t)
                 + 0.35 * math.sin(TAU * 2 * f * t) * math.exp(-t * 3.0)
                 + 0.12 * math.sin(TAU * 3 * f * t) * math.exp(-t * 5.0))
            self.lead[(start + i) % N] += s * env * amp

    def drone(self, midi, amp=0.05):
        """持续的低音,两轮慢慢起伏(循环里整数圈)。"""
        f = loop_hz(hz(midi))
        f2 = loop_hz(hz(midi) * 2)
        for i in range(N):
            t = i / SR
            swell = 0.8 + 0.2 * math.sin(TAU * 2.0 * t / LOOP_S)
            self.pad[i] += (math.sin(TAU * f * t) + 0.3 * math.sin(TAU * f2 * t)) * amp * swell

    def mix(self) -> list[float]:
        # 铺底过一个一阶低通(更软),循环两遍让滤波器在循环点也连续
        a = math.exp(-TAU * 900.0 / SR)
        y = 0.0
        pad = [0.0] * N
        for k in range(2 * N):
            y = (1 - a) * self.pad[k % N] + a * y
            if k >= N:
                pad[k - N] = y
        out = [pad[i] + self.lead[i] for i in range(N)]
        peak = max(1e-6, max(abs(v) for v in out))
        return [math.tanh(v / peak * 0.9) * 0.62 for v in out]


def menu() -> list[float]:
    t = Track()
    t.drone(38)                                             # D2
    chords = [[50, 53, 57, 62], [46, 50, 53, 58], [48, 53, 57, 60], [48, 52, 55, 60]]  # Dm Bb F C
    for k, ch in enumerate(chords):
        for n in ch:
            t.pad_note(n, k * 8, 8)
    for beat, n in [(0, 69), (1, 65), (2, 64), (3, 62),          # 姐姐动机 A F E D
                    (10, 74), (13, 72),
                    (16, 69), (17, 65), (18, 67), (19, 69),       # 变奏 A F G A
                    (26, 72), (28, 74), (30, 69)]:
        t.pluck(n, beat)
    return t.mix()


def outside() -> list[float]:
    t = Track()
    t.drone(38, amp=0.035)
    fifths = [[50, 57], [48, 55], [46, 53], [50, 57]]          # D-A, C-G, Bb-F, D-A
    for k, ch in enumerate(fifths):
        for n in ch:
            t.pad_note(n, k * 8, 8, amp=0.06, attack=2.5, release=3.0)
            t.pad_note(n + 12, k * 8 + 2, 6, amp=0.025, attack=2.5, release=3.0)
    for beat, n in [(5, 76), (9.5, 81), (14, 74), (21, 79), (25.5, 77), (29, 74)]:  # 很高很远
        t.pluck(n, beat, amp=0.09, decay=1.4, length=4.5)
    return t.mix()


def ending() -> list[float]:
    t = Track()
    t.drone(38, amp=0.04)
    chords = [[50, 54, 57, 62], [47, 50, 54, 59], [43, 50, 55, 59], [45, 49, 52, 57]]  # D Bm G A
    for k, ch in enumerate(chords):
        for n in ch:
            t.pad_note(n, k * 8, 8, amp=0.065)
    for beat, n in [(0, 69), (1, 66), (2, 64), (3, 62),          # 姐姐动机,大调 A F# E D
                    (12, 66), (14, 69),
                    (16, 71), (17, 69), (18, 66), (19, 62),       # B A F# D
                    (24, 64), (26, 66), (28, 62)]:                 # E F# —— 落在 D
        t.pluck(n, beat, amp=0.15, decay=1.8)
    return t.mix()


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = array.array("h", (int(max(-1.0, min(1.0, v)) * 32767) for v in samples))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(samples) / SR:.1f}s")


if __name__ == "__main__":
    for name, fn in [("menu", menu), ("outside", outside), ("ending", ending)]:
        write(name, fn())
