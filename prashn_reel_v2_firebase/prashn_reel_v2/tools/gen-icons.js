/**
 * ऐप का चिह्न (icon) और खुलने वाले पन्ने का लोगो बनाता है.
 *
 *   node tools/gen-icons.js
 *
 * कोई बाहरी पैकेज नहीं चाहिए — PNG यहीं बनती है, zlib Node में पहले से है.
 * इसीलिए ImageMagick या Python लगाने की ज़रूरत नहीं पड़ी.
 *
 * चिह्न का भाव: ब्रह्मास्त्र यानी दिव्य अस्त्र — इसलिए ऊपर जाता सुनहरा बाण,
 * गहरे ink पर. रंग वही हैं जो ऐप के भीतर हैं (lib/models.dart की P श्रेणी),
 * ताकि चिह्न और ऐप एक ही चीज़ लगें.
 *
 * किनारे smooth रखने के लिए supersampling नहीं, signed distance की गणना है —
 * हर बिंदु की आकृति से दूरी निकालकर उसी से alpha तय होता है. इससे छोटे
 * आकार (48px) पर भी बाण की नोक फटती नहीं.
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.join(__dirname, '..');

/* ───────────────────────── PNG लिखना ───────────────────────── */

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'latin1'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

/** RGBA बाइट्स को PNG फ़ाइल में बदलता है. */
function encodePng(width, height, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;   // हर रंग 8 बिट
  ihdr[9] = 6;   // RGBA
  // 10,11,12 = deflate, कोई filter नहीं, interlace नहीं — तीनों 0

  // हर पंक्ति के आगे एक filter बाइट लगती है
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* ───────────────────────── आकृति की दूरी ───────────────────────── */

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const mix = (a, b, t) => a + (b - a) * t;

/** बिंदु से रेखाखंड की दूरी. */
function segDist(px, py, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay;
  const wx = px - ax, wy = py - ay;
  const t = clamp((wx * vx + wy * vy) / (vx * vx + vy * vy), 0, 1);
  const dx = wx - vx * t, dy = wy - vy * t;
  return Math.hypot(dx, dy);
}

/**
 * बहुभुज की signed distance — भीतर ऋणात्मक, बाहर धनात्मक.
 * (उत्तल-अवतल दोनों पर चलती है, इसलिए बाण को टुकड़ों में तोड़ना नहीं पड़ा.)
 */
function polyDist(px, py, pts) {
  let d = Infinity;
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i];
    const [xj, yj] = pts[j];
    d = Math.min(d, segDist(px, py, xi, yi, xj, yj));
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside ? -d : d;
}

/** गोल कोनों वाले वर्ग की signed distance. */
function roundRectDist(px, py, cx, cy, half, r) {
  const qx = Math.abs(px - cx) - (half - r);
  const qy = Math.abs(py - cy) - (half - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}

/**
 * बाण — 100×100 की जगह में, ऊपर नोक.
 *
 * नीचे का V उसी बहुभुज का हिस्सा है (पंख जैसा), इसलिए अलग से घटाना नहीं पड़ता.
 */
const ARROW = [
  [50, 8],      // नोक
  [61, 40],     // फल का दाहिना छोर
  [55.5, 40],
  [55.5, 58],   // डंडी
  [67, 71],     // दाहिना पंख — पीछे की ओर झुका
  [55.5, 66],
  [55.5, 88],
  [50, 93],     // नीचे की नोक
  [44.5, 88],
  [44.5, 66],
  [33, 71],     // बायाँ पंख
  [44.5, 58],
  [44.5, 40],
  [39, 40],     // फल का बायाँ छोर
];

/* ───────────────────────── रंग ───────────────────────── */

// ये lib/models.dart की P श्रेणी से मेल खाते हैं
const INK_DEEP = [0x17, 0x11, 0x0b];
const INK_LIFT = [0x3a, 0x2b, 0x1c];
const GOLD_HI = [0xf2, 0xcf, 0x6e];
const GOLD_LO = [0xb0, 0x82, 0x1a];

/**
 * एक चिह्न बनाता है.
 *
 * @param size        पिक्सेल में चौड़ाई/ऊँचाई
 * @param plate       true = गहरी गोल-कोनों वाली तख़्ती; false = सिर्फ़ बाण (पारदर्शी)
 */
function render(size, { plate = true } = {}) {
  const buf = Buffer.alloc(size * size * 4);

  // बाण को तख़्ती के भीतर थोड़ा छोटा रखते हैं, ताकि किनारे से चिपके नहीं
  const inset = plate ? 0.13 : 0.04;
  const scale = size * (1 - 2 * inset) / 100;
  const originX = size * inset + (size * (1 - 2 * inset) - 100 * scale) / 2;
  const originY = originX;

  const half = size / 2;
  const plateRadius = size * 0.225;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const px = x + 0.5;
      const py = y + 0.5;

      let r = 0, g = 0, b = 0, a = 0;

      if (plate) {
        const dPlate = roundRectDist(px, py, half, half, half, plateRadius);
        const cover = clamp(0.5 - dPlate, 0, 1);
        if (cover > 0) {
          // ऊपर-बाएँ से हल्की रोशनी — सपाट गहरा रंग मरा हुआ लगता है
          const t = clamp(Math.hypot(px - size * 0.34, py - size * 0.28) / (size * 0.9), 0, 1);
          r = mix(INK_LIFT[0], INK_DEEP[0], t);
          g = mix(INK_LIFT[1], INK_DEEP[1], t);
          b = mix(INK_LIFT[2], INK_DEEP[2], t);
          a = cover;
        }
      }

      // फल के पीछे हल्की आभा — अस्त्र का तेज. बहुत हल्की रखी है,
      // वरना 48px पर धब्बे जैसी दिखने लगती है.
      if (plate && a > 0) {
        const gx = originX + 50 * scale;
        const gy = originY + 38 * scale;
        const gd = Math.hypot(px - gx, py - gy) / (size * 0.42);
        const glow = Math.pow(clamp(1 - gd, 0, 1), 2.2) * 0.30;
        r = mix(r, GOLD_LO[0], glow);
        g = mix(g, GOLD_LO[1], glow);
        b = mix(b, GOLD_LO[2], glow);
      }

      // बाण
      const ax = (px - originX) / scale;
      const ay = (py - originY) / scale;
      const dArrow = polyDist(ax, ay, ARROW) * scale;
      const arrowCover = clamp(0.5 - dArrow, 0, 1);

      if (arrowCover > 0) {
        const t = clamp((ay - 14) / 66, 0, 1);
        const gr = mix(GOLD_HI[0], GOLD_LO[0], t);
        const gg = mix(GOLD_HI[1], GOLD_LO[1], t);
        const gb = mix(GOLD_HI[2], GOLD_LO[2], t);

        // सोने को नीचे वाले रंग पर चढ़ाते हैं
        const na = arrowCover + a * (1 - arrowCover);
        if (na > 0) {
          r = (gr * arrowCover + r * a * (1 - arrowCover)) / na;
          g = (gg * arrowCover + g * a * (1 - arrowCover)) / na;
          b = (gb * arrowCover + b * a * (1 - arrowCover)) / na;
          a = na;
        }
      }

      const i = (y * size + x) * 4;
      buf[i] = Math.round(r);
      buf[i + 1] = Math.round(g);
      buf[i + 2] = Math.round(b);
      buf[i + 3] = Math.round(a * 255);
    }
  }

  return encodePng(size, size, buf);
}

/* ───────────────────────── लिखना ───────────────────────── */

function write(rel, data) {
  const full = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, data);
  console.log(`   ${rel}  (${(data.length / 1024).toFixed(1)} KB)`);
}

const RES = 'android/app/src/main/res';

// लॉन्चर चिह्न — पुराने फ़ोन इन्हीं PNG को दिखाते हैं
const LAUNCHER = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
// खुलते समय दिखने वाला लोगो
const SPLASH = { mdpi: 120, hdpi: 180, xhdpi: 240, xxhdpi: 360, xxxhdpi: 480 };

console.log('\nलॉन्चर चिह्न:');
for (const [d, s] of Object.entries(LAUNCHER)) {
  write(`${RES}/mipmap-${d}/ic_launcher.png`, render(s, { plate: true }));
}

console.log('\nखुलने वाले पन्ने का लोगो:');
for (const [d, s] of Object.entries(SPLASH)) {
  write(`${RES}/drawable-${d}/splash_logo.png`, render(s, { plate: true }));
}

console.log('\nऐप के भीतर के लिए:');
write('assets/images/logo.png', render(512, { plate: true }));

/* ── Android 8+ का adaptive चिह्न — वही बाण, पर vector रूप में ──
 *
 * PNG और vector दोनों इसी ARROW से बनते हैं. इसलिए बाण बदलने पर दोनों साथ
 * बदलते हैं — एक पुराना, एक नया वाली गड़बड़ नहीं होती.
 */

// 108 की जगह में, बीच से 0.8 गुना. गोल mask वाले लॉन्चर किनारे काट देते हैं,
// इसलिए बाण को safe zone (बीच से 35.6 त्रिज्या) के भीतर रखना पड़ता है.
const vecPt = ([x, y]) =>
  `${(54 + (x - 50) * 0.8).toFixed(1)},${(54 + (y - 50) * 0.8).toFixed(1)}`;
const arrowPath = `M${ARROW.map(vecPt).join(' L')} Z`;

const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');

console.log('\nadaptive चिह्न (Android 8+):');

write(
  `${RES}/drawable/ic_launcher_background.xml`,
  Buffer.from(
    `<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen-icons.js से बनी — हाथ से न बदलें. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
  <path android:pathData="M0,0 h108 v108 h-108 z">
    <aapt:attr name="android:fillColor">
      <gradient android:type="linear"
          android:startX="20" android:startY="12"
          android:endX="96" android:endY="104"
          android:startColor="${hex(INK_LIFT)}" android:endColor="${hex(INK_DEEP)}" />
    </aapt:attr>
  </path>
</vector>
`,
    'utf8',
  ),
);

write(
  `${RES}/drawable/ic_launcher_foreground.xml`,
  Buffer.from(
    `<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen-icons.js से बनी — हाथ से न बदलें. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
  <path android:pathData="${arrowPath}">
    <aapt:attr name="android:fillColor">
      <gradient android:type="linear"
          android:startX="54" android:startY="20"
          android:endX="54" android:endY="89"
          android:startColor="${hex(GOLD_HI)}" android:endColor="${hex(GOLD_LO)}" />
    </aapt:attr>
  </path>
</vector>
`,
    'utf8',
  ),
);

console.log('\n✅ हो गया. नया APK बनाना न भूलें.\n');
