/**
 * बाँटने लायक़ APK बनाता है.
 *
 *   node tools/build-apk.js
 *
 * करता क्या है:
 *   • flutter build apk --release  चलाता है
 *   • बनी हुई app-release.apk को  dist/Brahmastra-<version>.apk  नाम से रखता है
 *   • बताता है कि वह किस key से sign हुई
 *
 * नाम बदलने का काम यहाँ इसलिए है, gradle में नहीं: AGP 8 में output का नाम
 * बदलने वाला पुराना तरीक़ा हट चुका है, और नया तरीक़ा इतने-से काम के लिए
 * ज़्यादा उलझा हुआ है. यहाँ एक copy से काम चल जाता है.
 *
 * ⚠️  sign होने वाली key android/key.properties से आती है. वह फ़ाइल या
 *     android/brahmastra-release.jks खो गई तो पुराने फ़ोनों पर update
 *     कभी नहीं चढ़ेगा — दोनों का backup कहीं और रखिए.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const BUILT = path.join(ROOT, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
const DIST = path.join(ROOT, 'dist');

/* ── version pubspec से ── */
const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
const m = /^version:\s*([^\s+]+)/m.exec(pubspec);
if (!m) {
  console.error('❌ pubspec.yaml में version नहीं मिला.');
  process.exit(1);
}
const version = m[1];

/* ── build ── */
console.log(`\n🔨 ब्रह्मास्त्र ${version} बन रही है — दो-तीन मिनट लग सकते हैं.\n`);
try {
  execSync('flutter build apk --release', { cwd: ROOT, stdio: 'inherit' });
} catch {
  console.error('\n❌ build नहीं हुई. ऊपर की गड़बड़ी देखिए.\n');
  process.exit(1);
}

if (!fs.existsSync(BUILT)) {
  console.error(`\n❌ APK मिली नहीं: ${BUILT}\n`);
  process.exit(1);
}

/* ── सही नाम से रखना ── */
fs.mkdirSync(DIST, { recursive: true });
const out = path.join(DIST, `Brahmastra-${version}.apk`);
fs.copyFileSync(BUILT, out);

const mb = (fs.statSync(out).size / (1024 * 1024)).toFixed(1);

/* ── किस key से sign हुई ── */
let signer = '(जाँच नहीं हो पाई)';
try {
  const props = fs.readFileSync(path.join(ROOT, 'android', 'local.properties'), 'utf8');
  const sdk = /^sdk\.dir=(.*)$/m.exec(props)[1].replace(/\\\\/g, '\\');
  const tools = fs.readdirSync(path.join(sdk, 'build-tools')).sort().pop();
  const apksigner = path.join(sdk, 'build-tools', tools, 'apksigner.bat');
  // Node 20 से .bat/.cmd बिना shell के नहीं चलते (सुरक्षा वाला बदलाव), और
  // shell के साथ अलग से args देने पर Node चेतावनी देता है. इसलिए पूरी
  // पंक्ति एक साथ — रास्तों पर quote, क्योंकि उनमें जगह हो सकती है.
  const txt = execSync(`"${apksigner}" verify --print-certs "${out}"`, {
    encoding: 'utf8',
  });
  signer = (/Signer #1 certificate DN: (.*)/.exec(txt) || [, signer])[1].trim();
} catch {
  // apksigner न मिले तो भी APK ठीक है — सिर्फ़ बताया नहीं जा सका
}

console.log(`
✅ तैयार:  dist/Brahmastra-${version}.apk   (${mb} MB)

   sign हुई:  ${signer}

   यही एक फ़ाइल भेजिए — हर Android फ़ोन पर चलेगी.
`);

if (signer.includes('Android Debug')) {
  console.log('⚠️  यह debug key से sign हुई है — android/key.properties नहीं मिली.');
  console.log('   ऐसी APK मत बाँटिए: आगे चलकर इस पर update नहीं चढ़ेगा.\n');
}
