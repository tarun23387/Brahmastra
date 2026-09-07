/**
 * dist/ की APK को उसी Wi-Fi पर फ़ोन तक पहुँचाने वाला छोटा सर्वर.
 *
 *   node tools/apkserve.js
 *
 * फ़ोन के ब्राउज़र में जो पता दिखे वह खोलिए, APK पर टैप कीजिए, बस.
 * USB या adb की ज़रूरत नहीं — काम की बात तब, जब adb PATH पर न हो.
 *
 * ── दो बातें ध्यान रखने की ──
 *
 * 1. लैपटॉप और फ़ोन एक ही Wi-Fi पर हों. मोबाइल डेटा चालू हो तो फ़ोन
 *    पता खोल ही नहीं पाएगा.
 *
 * 2. `application/vnd.android.package-archive` भेजना ज़रूरी है. सादे
 *    octet-stream पर कुछ फ़ोन APK को "अज्ञात फ़ाइल" कहकर खोलने से ही
 *    मना कर देते हैं.
 *
 * ⚠️  यह सर्वर सब जगह (0.0.0.0) सुनता है — यानी उस Wi-Fi पर जो भी है,
 *     वह APK उतार सकता है. काम हो जाए तो Ctrl+C दबा दीजिए. घर के
 *     राउटर पर ठीक है; किसी सार्वजनिक Wi-Fi पर मत चलाइए.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');

const PORT = Number(process.env.PORT || 8100);
const DIST = path.join(__dirname, '..', 'dist');

if (!fs.existsSync(DIST)) {
  console.error(`❌ dist/ मिली नहीं: ${DIST}`);
  console.error('   पहले  node tools/build-apk.js  चलाइए.');
  process.exit(1);
}

/**
 * dist/ की APK — नई पहले.
 *
 * fs.Stats को फैलाकर (...stat) मत लिखिए — size/mtime उसके prototype पर
 * हैं, own property नहीं, इसलिए फैलाने पर वे साथ नहीं आते और mtime
 * undefined निकलता है.
 */
function apks() {
  return fs
    .readdirSync(DIST)
    .filter((f) => f.endsWith('.apk'))
    .map((f) => {
      const st = fs.statSync(path.join(DIST, f));
      return { name: f, size: st.size, mtime: st.mtime, mtimeMs: st.mtimeMs };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
}

/** इस मशीन का LAN पता — 169.254.* वाले छोड़कर, वे किसी काम के नहीं. */
function lanIPs() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((n) => n.family === 'IPv4' && !n.internal && !n.address.startsWith('169.254.'))
    .map((n) => n.address);
}

const mb = (n) => (n / (1024 * 1024)).toFixed(1);

const page = (list) => `<!doctype html>
<html lang="hi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ब्रह्मास्त्र — APK</title>
<style>
  :root { color-scheme: dark }
  body { margin:0; padding:28px 20px; background:#17110b; color:#E8DAC2;
         font:16px/1.7 "Nirmala UI",system-ui,sans-serif }
  h1 { margin:0 0 4px; font-size:26px; color:#f2cf6e }
  p.sub { margin:0 0 26px; opacity:.65; font-size:14px }
  a.apk { display:block; margin-bottom:12px; padding:16px 18px; border-radius:12px;
          background:#241a10; border:1px solid #3a2b1c; color:#E8DAC2;
          text-decoration:none }
  a.apk:first-of-type { border-color:#f2cf6e }
  b { color:#f2cf6e; font-weight:600 }
  small { display:block; opacity:.6; font-size:13px; margin-top:3px }
  .note { margin-top:26px; font-size:13.5px; opacity:.7; border-top:1px solid #3a2b1c;
          padding-top:16px }
</style></head><body>
<h1>ब्रह्मास्त्र</h1>
<p class="sub">APK पर टैप कीजिए — सबसे ऊपर वाली सबसे नई है।</p>
${list
  .map(
    (a) => `<a class="apk" href="/apk/${encodeURIComponent(a.name)}">
  <b>${a.name}</b>
  <small>${mb(a.size)} MB · ${a.mtime.toLocaleString('hi-IN')}</small></a>`
  )
  .join('\n')}
<p class="note">पहली बार में फ़ोन “अज्ञात स्रोत से इंस्टॉल” की अनुमति माँगेगा —
ब्राउज़र को वह अनुमति दे दीजिए। पहले से ऐप लगी हो तो यह उसी के ऊपर चढ़ जाएगी
और लॉगिन बना रहेगा।</p>
</body></html>`;

http
  .createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);

    if (url === '/') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      return res.end(page(apks()));
    }

    if (url.startsWith('/apk/')) {
      // basename — ताकि ../ से dist के बाहर कुछ न परोसा जा सके.
      const name = path.basename(url.slice(5));
      const file = path.join(DIST, name);
      if (!name.endsWith('.apk') || !fs.existsSync(file)) {
        res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
        return res.end('APK नहीं मिली');
      }
      console.log(`  ⬇️  ${name} → ${req.socket.remoteAddress}`);
      res.writeHead(200, {
        'content-type': 'application/vnd.android.package-archive',
        'content-length': fs.statSync(file).size,
        'content-disposition': `attachment; filename="${name}"`,
      });
      return fs.createReadStream(file).pipe(res);
    }

    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('कुछ नहीं है यहाँ');
  })
  .listen(PORT, '0.0.0.0', () => {
    const list = apks();
    console.log(`\n  📦 dist/ में ${list.length} APK — सबसे नई: ${list[0]?.name || '(कोई नहीं)'}\n`);
    console.log('  फ़ोन के ब्राउज़र में खोलिए (वही Wi-Fi हो):\n');
    for (const ip of lanIPs()) console.log(`      http://${ip}:${PORT}`);
    console.log('\n  बंद करने के लिए Ctrl+C.\n');
  });
