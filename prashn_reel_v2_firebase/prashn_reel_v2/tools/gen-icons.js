/**
 * ऐप का चिह्न (icon), खुलने वाले पन्ने का लोगो और Play Store का चिह्न बनाता है.
 *
 *   node tools/gen-icons.js
 *
 * चिह्न का भाव: खुली किताब से ऊपर उठता बाण — "ज्ञान जो लक्ष्य भेदे".
 * बाण की नोक मंदिर-शिखर जैसी, किताब की सुनहरी जिल्द नीचे से झाँकती.
 * क्रीम पर मैरून और सोना — वही रंग जो ऐप के भीतर हैं (lib/models.dart की P).
 *
 * ── अक्टूबर 2026 का बदलाव ──
 *
 * पहले यहाँ गहरे ink की तख़्ती पर अकेला सुनहरा बाण था. काली पृष्ठभूमि
 * क्रीम ऐप के साथ मेल नहीं खाती थी और बाण से यह पता नहीं चलता था कि यह
 * पढ़ाई का ऐप है. design/logo-2026-10/ में तीन विकल्प बने, "A" चुना गया.
 *
 * ── एक ही स्रोत ──
 *
 * आकृति नीचे SHAPES में है (1024×1024 की जगह में, SVG path). उसी से:
 *   • PNG (लॉन्चर, splash, ऐप के भीतर, Play Store) — Chrome headless से
 *   • Android के vector (adaptive चिह्न, Android 13 का monochrome, notification)
 * यानी आकृति बदलनी हो तो सिर्फ़ SHAPES बदलिए, सब साथ बदलेगा.
 *
 * Chrome ज़रूरी है (PNG उसी से बनती है). पहले यह script बिना किसी बाहरी
 * चीज़ के अपने हिसाब से PNG बनाती थी, पर वह तरीक़ा सिर्फ़ एक बहुभुज बाण
 * खींच सकता था — घुमावदार किताब के लिए SVG ही ठीक है.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const RES = 'android/app/src/main/res';

const CREAM = '#F7F3EC';
const MAROON = '#8C3A1E';
const MAROON_DEEP = '#76301A';
const GOLD = '#C9A227';

/* ───────────────────────── आकृति ───────────────────────── */

// 1024×1024 में. क्रम मायने रखता है — बाद वाली ऊपर चढ़ती है.
const SHAPES = [
  // किताब की सुनहरी जिल्द (पन्नों के नीचे से झाँकती)
  { fill: GOLD, d: 'M512,640 C440,596 352,590 250,618 L250,782 C352,758 440,762 512,806 C584,762 672,758 774,782 L774,618 C672,590 584,596 512,640 Z' },
  // पन्ने — बायाँ थोड़ा गहरा, ताकि किताब में गहराई दिखे
  { fill: MAROON_DEEP, d: 'M502,620 C438,576 356,570 270,592 L270,752 C356,732 438,736 502,778 Z' },
  { fill: MAROON, d: 'M522,620 C586,576 668,570 754,592 L754,752 C668,732 586,736 522,778 Z' },
  // बाण का दंड
  { fill: MAROON, d: 'M494,372 H530 Q538,372 538,380 V626 Q538,634 530,634 H494 Q486,634 486,626 V380 Q486,372 494,372 Z' },
  // सुनहरा कंगन
  { fill: GOLD, d: 'M479,372 H545 Q556,372 556,383 V395 Q556,406 545,406 H479 Q468,406 468,395 V383 Q468,372 479,372 Z' },
  // फलक (नोक) — मंदिर-शिखर जैसा
  { fill: MAROON, d: 'M512,188 C562,252 612,318 632,392 C594,370 556,364 512,374 C468,364 430,370 392,392 C412,318 462,252 512,188 Z' },
  { fill: GOLD, d: 'M512,262 C540,298 562,334 572,368 C552,360 532,357 512,359 C492,357 472,360 452,368 C462,334 484,298 512,262 Z' },
];

// आकृति का बीच (1024 की जगह में) — x 250…774, y 188…806
const CX = 512;
const CY = 497;

/** रंगीन आकृति का SVG. plate: 'square' | 'rounded' | null (पारदर्शी). */
function svg({ plate }) {
  const bg =
    plate === 'square' ? `<rect width="1024" height="1024" fill="${CREAM}"/>`
    : plate === 'rounded' ? `<rect width="1024" height="1024" rx="230" fill="${CREAM}"/>`
    : '';
  const body = SHAPES.map((s) => `<path fill="${s.fill}" d="${s.d}"/>`).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="100%" height="100%">${bg}${body}</svg>`;
}

/* ───────────────────────── PNG — Chrome headless से ───────────────────────── */

function findChrome() {
  const candidates = [
    process.env.CHROME,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ].filter(Boolean);
  const hit = candidates.find((c) => fs.existsSync(c));
  if (!hit) throw new Error('Chrome/Edge नहीं मिला — CHROME=<path> देकर चलाइए');
  return hit;
}

const CHROME = findChrome();
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'brahmastra-icons-'));

function png(size, opts) {
  const html = path.join(TMP, 'icon.html');
  const out = path.join(TMP, 'icon.png');
  fs.writeFileSync(
    html,
    `<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}` +
      `div{width:${size}px;height:${size}px}</style></head><body><div>${svg(opts)}</div></body></html>`,
  );
  if (fs.existsSync(out)) fs.unlinkSync(out);
  execFileSync(
    CHROME,
    [
      '--headless=new',
      '--disable-gpu',
      '--hide-scrollbars',
      '--force-device-scale-factor=1',
      '--default-background-color=00000000',
      `--window-size=${size},${size}`,
      `--screenshot=${out}`,
      'file:///' + html.replace(/\\/g, '/'),
    ],
    { stdio: 'ignore' },
  );
  return fs.readFileSync(out);
}

function write(rel, data) {
  const full = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, data);
  console.log(`   ${rel}  (${(data.length / 1024).toFixed(1)} KB)`);
}

// लॉन्चर चिह्न — adaptive न समझने वाले लॉन्चर इन्हीं PNG को दिखाते हैं
const LAUNCHER = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
// खुलते समय दिखने वाला लोगो — lib/app_gate.dart का SplashPage 120 पर दिखाता है
const SPLASH = { mdpi: 120, hdpi: 180, xhdpi: 240, xxhdpi: 360, xxxhdpi: 480 };

console.log('\nलॉन्चर चिह्न:');
for (const [d, s] of Object.entries(LAUNCHER)) {
  write(`${RES}/mipmap-${d}/ic_launcher.png`, png(s, { plate: 'rounded' }));
}

console.log('\nखुलने वाले पन्ने का लोगो:');
for (const [d, s] of Object.entries(SPLASH)) {
  write(`${RES}/drawable-${d}/splash_logo.png`, png(s, { plate: 'rounded' }));
}

console.log('\nऐप के भीतर के लिए:');
write('assets/images/logo.png', png(512, { plate: 'rounded' }));

// Play Store — पूरा चौकोर, बिना पारदर्शिता; कोने Play ख़ुद गोल करता है.
// (पारदर्शी pixel वाला चिह्न Play का uploader अस्वीकार कर देता है.)
console.log('\nPlay Store:');
write('play-listing/store-icon-512.png', png(512, { plate: 'square' }));
write('play-listing/icon-512.png', png(512, { plate: 'rounded' }));

/* ───────────────────────── Android vector ───────────────────────── */

// 1024 की आकृति को 108dp की adaptive जगह में. गोल mask वाले लॉन्चर सिर्फ़
// बीच का 66dp व्यास पक्का दिखाते हैं; किताब के कोने बीच से ~387 दूर हैं,
// इसलिए 387 → 33dp.
const ADAPTIVE_SCALE = 33 / 387;

function vectorGroup(scale, size, { mono = null } = {}) {
  const tx = (size / 2 - CX * scale).toFixed(3);
  const ty = (size / 2 - CY * scale).toFixed(3);
  const paths = SHAPES.map(
    (s) => `    <path android:fillColor="${mono || s.fill}" android:pathData="${s.d}" />`,
  ).join('\n');
  return `  <group android:translateX="${tx}" android:translateY="${ty}"
      android:scaleX="${scale.toFixed(5)}" android:scaleY="${scale.toFixed(5)}">
${paths}
  </group>`;
}

function vector(size, body, comment) {
  return Buffer.from(
    `<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen-icons.js से बनी — हाथ से न बदलें.${comment ? '\n     ' + comment : ''} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${size}dp" android:height="${size}dp"
    android:viewportWidth="${size}" android:viewportHeight="${size}">
${body}
</vector>
`,
    'utf8',
  );
}

console.log('\nadaptive चिह्न (Android 8+):');
write(
  `${RES}/drawable/ic_launcher_background.xml`,
  vector(108, `  <path android:fillColor="${CREAM}" android:pathData="M0,0 h108 v108 h-108 z" />`),
);
write(`${RES}/drawable/ic_launcher_foreground.xml`, vector(108, vectorGroup(ADAPTIVE_SCALE, 108)));
// Android 13 के "themed icons" — फ़ोन अपने रंग में रँगता है, सिर्फ़ आकार चाहिए
write(
  `${RES}/drawable/ic_launcher_monochrome.xml`,
  vector(108, vectorGroup(ADAPTIVE_SCALE, 108, { mono: '#FFFFFFFF' })),
);
write(
  `${RES}/mipmap-anydpi-v26/ic_launcher.xml`,
  Buffer.from(
    `<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen-icons.js से बनी — हाथ से न बदलें.
     Android 8 और उसके बाद वाले फ़ोन इसे इस्तेमाल करते हैं; पुराने
     mipmap-*/ic_launcher.png लेते हैं. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
`,
    'utf8',
  ),
);

// Notification bar — एक-रंगी (Android सिर्फ़ alpha देखता है). 24dp में
// आकृति पूरी भरती है; थोड़ी जगह किनारे पर छोड़ी है.
console.log('\nnotification चिह्न:');
write(
  `${RES}/drawable/ic_stat_notify.xml`,
  vector(
    24,
    vectorGroup(22 / 640, 24, { mono: '#FFFFFFFF' }),
    'प्रश्न-घंटी (lib/reminders.dart) का छोटा चिह्न. रंगीन चिह्न वहाँ सफ़ेद\n     चौकोर बनकर दिखता है, इसलिए एक-रंगी. res/raw/keep.xml इसे R8 से बचाता है.',
  ),
);

fs.rmSync(TMP, { recursive: true, force: true });
console.log('\n✅ हो गया. नया APK/AAB बनाना न भूलें.\n');
