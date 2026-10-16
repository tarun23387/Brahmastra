"""
ऐप का चिह्न (icon), खुलने वाले पन्ने का लोगो और Play Store का चिह्न बनाता है.

    python tools/gen_icons.py

स्रोत: design/logo-2026-10/user-sketch.webp — धनुष, बाण, खुली किताब और कोने
में सुनहरा लक्ष्य, क्रीम काग़ज़ पर pencil sketch. 17 अक्टूबर 2026 को चुना गया
(पहले वाला "किताब + बाण" flat vector बहुत साधारण लगा).

── स्रोत image से क्या काटा जाता है ──

image में पहले से गोल कोनों वाली तख़्ती, उसकी छाया और नीचे दाएँ Gemini का
✦ निशान है. Android और Play अपने कोने ख़ुद गोल करते हैं, इसलिए तख़्ती के
भीतर का एक चौकोर हिस्सा (CROP) काटा जाता है — उसके चारों कोने क्रीम हैं,
यानी न छाया आती है, न ✦. image बदलें तो CROP फिर से नापिए.

── बाहर क्या बनता है ──

  • लॉन्चर PNG (mipmap-*) — गोल कोनों वाली तख़्ती, पुराने लॉन्चरों के लिए
  • adaptive चिह्न (Android 8+) — foreground PNG + क्रीम background
  • splash_logo और assets/images/logo.png — खुलने वाले पन्ने के लिए
  • play-listing/store-icon-512.png — पूरा चौकोर, बिना पारदर्शिता

notification का चिह्न (drawable/ic_stat_notify.xml) यहाँ नहीं बनता — वह
एक-रंगी vector है, sketch से नहीं बन सकता. हाथ से बना है.

Pillow चाहिए:  pip install pillow
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Windows console (cp1252) हिंदी नहीं छाप पाता
sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
SRC = ROOT / "design/logo-2026-10/user-sketch.webp"

# स्रोत (2000×2000) में कलाकृति वाला चौकोर — तख़्ती के भीतर, कोने क्रीम
CROP = (273, 287, 1713, 1727)

# तख़्ती का काग़ज़ी रंग — कटे हुए हिस्से के किनारे इसी से मिलते हैं
PAPER = (253, 246, 235, 255)  # #FDF6EB

# कलाकृति के सबसे दूर के सिरे (धनुष के छोर) कटे हुए चौकोर के बीच से
# इतनी दूरी पर हैं — चौकोर की आधी चौड़ाई के अनुपात में. नीचे adaptive में
# काम आता है; measure_reach() से निकाला गया.
def measure_reach(art: Image.Image) -> float:
    g = art.convert("L")
    w, h = g.size
    cx, cy = w / 2, h / 2
    far = 0.0
    px = g.load()
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            if px[x, y] < 200:  # रेखा (काग़ज़ नहीं)
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                far = max(far, d)
    return far / (w / 2)


def art() -> Image.Image:
    return Image.open(SRC).convert("RGBA").crop(CROP)


def on_paper(size: int, art_frac: float, rounded: bool) -> Image.Image:
    """size×size पर काग़ज़, बीच में कलाकृति (चौड़ाई का art_frac हिस्सा)."""
    canvas = Image.new("RGBA", (size, size), PAPER)
    a = art()
    n = round(size * art_frac)
    a = a.resize((n, n), Image.LANCZOS)
    off = (size - n) // 2
    canvas.alpha_composite(a, (off, off))
    if rounded:
        mask = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * 0.225), fill=255
        )
        canvas.putalpha(mask.resize((size, size), Image.LANCZOS))
    return canvas


def write(rel: str, img: Image.Image, rgb: bool = False) -> None:
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(p, optimize=True)
    print(f"   {rel}  ({p.stat().st_size / 1024:.1f} KB)")


def write_text(rel: str, text: str) -> None:
    p = ROOT / rel
    p.write_text(text, encoding="utf-8", newline="\n")
    print(f"   {rel}")


reach = measure_reach(art())

print("\nलॉन्चर चिह्न:")
for d, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    write(f"{RES.relative_to(ROOT)}/mipmap-{d}/ic_launcher.png", on_paper(s, 0.86, True))

print("\nखुलने वाले पन्ने का लोगो:")
for d, s in {"mdpi": 120, "hdpi": 180, "xhdpi": 240, "xxhdpi": 360, "xxxhdpi": 480}.items():
    write(f"{RES.relative_to(ROOT)}/drawable-{d}/splash_logo.png", on_paper(s, 0.86, True))

print("\nऐप के भीतर के लिए:")
write("assets/images/logo.png", on_paper(512, 0.86, True))

# Play Store: पूरा चौकोर, बिना पारदर्शिता. Play कोने ~20% गोल करता है,
# धनुष के छोर उनसे बचें इसलिए थोड़ी जगह.
print("\nPlay Store:")
write("play-listing/store-icon-512.png", on_paper(512, 0.88, False), rgb=True)

# adaptive: 108dp में से लॉन्चर बीच का ~72dp व्यास दिखाते हैं (गोल mask).
# धनुष के छोर (reach) उस घेरे के भीतर रहें — 34dp त्रिज्या, थोड़ी साँस के साथ.
frac = (34 / 108) * 2 / reach
print(f"\nadaptive चिह्न (Android 8+) — कलाकृति {frac:.0%} चौड़ाई:")
for d, s in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
    write(f"{RES.relative_to(ROOT)}/mipmap-{d}/ic_launcher_foreground.png", on_paper(s, frac, False))

write_text(
    "android/app/src/main/res/drawable/ic_launcher_background.xml",
    """<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen_icons.py से बनी — हाथ से न बदलें. sketch के काग़ज़ का रंग. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#FDF6EB" android:pathData="M0,0 h108 v108 h-108 z" />
</vector>
""",
)
write_text(
    "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
    """<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen_icons.py से बनी — हाथ से न बदलें.
     Android 8 और उसके बाद वाले फ़ोन इसे इस्तेमाल करते हैं; पुराने
     mipmap-*/ic_launcher.png लेते हैं. monochrome (Android 13 के themed
     icons) नहीं है — pencil sketch का एक-रंगी रूप पहचान में नहीं आता. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""",
)

print("\n✅ हो गया. नया APK/AAB बनाना न भूलें.\n")
