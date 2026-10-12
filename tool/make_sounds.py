"""Derlemede çalışır: Mera Bilgisi ortam sesleri: rüzgâr, yağmur, dalga, sakin deniz (kendi ürettiğimiz, telifsiz döngüler)."""
import sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 32000
DUR = 16.0
N = int(SR * DUR)
rng = np.random.default_rng(7)
t = np.arange(N) / SR


def loopify(x, fade=1.5):
    """Sonu başına çapraz geçişle bağlar: döngü dikişsiz olur."""
    f = int(SR * fade)
    head, tail = x[:f], x[-f:]
    w = np.linspace(0, 1, f)
    mixed = tail * (1 - w) + head * w
    return np.concatenate([mixed, x[f:-f]])


def lp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), 'low')
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return signal.lfilter(b, a, x)


def smooth_noise(rate, n=N + SR * 2):
    """Yavaş değişen 0..1 zarf"""
    k = int(n / SR * rate) + 4
    pts = rng.random(k)
    xs = np.linspace(0, k - 1, n)
    env = np.interp(xs, np.arange(k), pts)
    return lp(env, rate * 2, 1)


def norm(x, peak=0.6):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def wind():
    n = N + SR * 2
    white = rng.standard_normal(n)
    env = 0.35 + 0.65 * smooth_noise(0.35, n)
    # uğultu: değişen merkez frekanslı bant geçiren gürültü
    body = lp(white, 500, 2) * env
    e1 = smooth_noise(0.22, n); e2 = smooth_noise(0.3, n)
    howl = bp(white, 210, 330, 2) * e1 + bp(white, 360, 520, 2) * e2 * 0.7
    howl = lp(howl, 900) * env ** 1.5
    x = body * 0.8 + howl * 2.0
    return loopify(norm(x[SR:SR + N + int(SR * 1.5)], 0.55))


def rain():
    n = N + SR * 2
    white = rng.standard_normal(n)
    hiss = bp(white, 1500, 9000, 2) * 0.35
    drops = np.zeros(n)
    count = int(n / SR * 900)
    pos = rng.integers(0, n - 400, count)
    amp = rng.random(count) ** 3
    click = np.exp(-np.arange(200) / 18.0) * np.sin(np.arange(200) * 2 * np.pi * 3200 / SR)
    for p, a in zip(pos, amp):
        drops[p:p + 200] += click * a
    drops = signal.lfilter(*signal.butter(2, 800 / (SR / 2), 'high'), drops)
    rumble = lp(white, 250) * 0.25
    x = hiss + drops * 0.9 + rumble
    return loopify(norm(x[SR:SR + N + int(SR * 1.5)], 0.5))


def waves(strength=1.0):
    n = N + SR * 2
    white = rng.standard_normal(n)
    tt = np.arange(n) / SR
    period = 5.3 if strength > 0.6 else 6.4
    # her dalga: yavaş yükselen, hızlı kırılan, uzun çekilen zarf
    phase = (tt % period) / period
    env = np.where(phase < 0.45, (phase / 0.45) ** 2.2, np.exp(-(phase - 0.45) * 5.5))
    env *= 0.75 + 0.25 * smooth_noise(0.15, n)
    crash = bp(white, 300, 4500, 2) * env ** 1.4
    wash = lp(white, 700) * env
    bed = lp(white, 160) * 0.35
    x = crash * (0.9 * strength + 0.25) + wash * 0.8 + bed
    if strength < 0.6:
        x = lp(x, 2600)
    return loopify(norm(x[SR:SR + N + int(SR * 1.5)], 0.5 if strength > 0.6 else 0.38))


if __name__ == '__main__':
    import os
    import subprocess
    import tempfile
    out = sys.argv[1]
    sadece_m4a = '--ios' in sys.argv  # macOS derlemesi: Homebrew ffmpeg'de Vorbis yok, iPhone'a .m4a yeter
    os.makedirs(out, exist_ok=True)
    for name, fn in [('ruzgar', wind), ('yagmur', rain), ('dalga', lambda: waves(1.0)), ('sakin', lambda: waves(0.35))]:
        y = fn()
        with tempfile.TemporaryDirectory() as td:
            wav = os.path.join(td, name + '.wav')
            wavfile.write(wav, SR, (y * 32767).astype(np.int16))
            if not sadece_m4a:
                subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', wav,
                                '-af', 'loudnorm=I=-22:TP=-3', '-ar', str(SR), '-c:a', 'libvorbis', '-q:a', '2',
                                os.path.join(out, name + '.ogg')], check=True)
            # iPhone için AAC (.m4a) — iOS Vorbis (.ogg) çalamaz
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', wav,
                            '-af', 'loudnorm=I=-22:TP=-3', '-ar', str(SR), '-c:a', 'aac', '-b:a', '64k',
                            os.path.join(out, name + '.m4a')], check=True)
        print(name, round(len(y) / SR, 1), 's', os.path.getsize(os.path.join(out, name + '.m4a')), 'bayt (m4a)')
