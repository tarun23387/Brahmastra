/**
 * PDF के पन्नों को तस्वीर बनाकर ब्राउज़र में दिखाता है.
 *
 *   node tools/pdfserve.js "C:/कहीं/pdf-वाला-फ़ोल्डर"
 *   फिर खोलिए: http://localhost:8099
 *
 * ── यह क्यों बना ──
 *
 * 3 सितंबर 2026 को UPPSC की तकनीकी भर्तियों के तीन मॉक टेस्ट PDF से
 * प्रश्न उतारने थे. `pdftotext` से हिंदी टूटी-फूटी निकली — उन PDF के
 * font का ToUnicode नक़्शा अधूरा है, इसलिए आधे अक्षर और कुछ मात्राएँ
 * निकलते ही ग़ायब हो जाती हैं:
 *
 *     असली:  कैश मेमोरी को CPU और मुख्य मेमोरी के बीच
 *     निकला: ै कश मेमोरी को CPU और मु य मेमोरीे क बीच
 *
 * अंग्रेज़ी बच जाती है, हिंदी नहीं. ऐसे पाठ से प्रश्न बनाना मतलब अंदाज़े
 * से हिंदी भरना — प्रश्न बैंक में अंदाज़ा सबसे ख़राब चीज़ है. इसलिए पन्नों
 * को pdf.js से canvas पर बनाकर आँख से पढ़ा जाता है.
 *
 * आगे भी जब किसी PDF से पाठ ठीक न निकले, यही रास्ता लीजिए.
 *
 * ── क्वेरी ──
 *
 *   /<फ़ाइल का नाम>?from=2&to=2&scale=1.7
 *
 * एक बार में एक ही पन्ना माँगिए — कई माँगने पर तस्वीर इतनी लंबी हो जाती
 * है कि अक्षर पढ़ने लायक नहीं रहते. scale 1.7 पर A4 पूरा दिखता भी है और
 * पढ़ा भी जाता है; बढ़ाने पर दाहिना किनारा कटने लगता है.
 *
 * ⚠️ सीधे application/pdf परोसने से काम नहीं चलता — ब्राउज़र उसे download
 * मान लेता है. इसीलिए HTML लपेटन ज़रूरी है.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const DIR = process.argv[2];
const PORT = Number(process.env.PORT || 8099);

if (!DIR || !fs.existsSync(DIR)) {
  console.error('❌ PDF वाला फ़ोल्डर दीजिए:  node tools/pdfserve.js "C:/…/फ़ोल्डर"');
  process.exit(1);
}

const PDFJS = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174';

const viewer = (file, from, to, scale, extra, up) => `<!doctype html><html><head><meta charset="utf-8">
<style>body{margin:0;background:#fff}canvas{display:block;margin:0 auto 8px;border-bottom:2px solid #c00}</style>
<script src="${PDFJS}/pdf.min.js"></script></head><body>
<div id="c"></div><script>
const ctx0 = (cv) => { const c = cv.getContext("2d"); c.fillStyle = "#fff"; c.fillRect(0, 0, cv.width, cv.height); return c; };
pdfjsLib.GlobalWorkerOptions.workerSrc='${PDFJS}/pdf.worker.min.js';
(async () => {
  const pdf = await pdfjsLib.getDocument('/raw/${encodeURIComponent(file)}').promise;
  // कुल पन्ने title में — बुलाने वाले को अलग से पूछना न पड़े.
  document.title = 'pages:' + pdf.numPages;
  const last = Math.min(${to}, pdf.numPages);
  for (let n = ${from}; n <= last; n++) {
    const p = await pdf.getPage(n);
    const vp = p.getViewport({ scale: ${scale} });
    const cv = document.createElement('canvas');
    cv.width = vp.width;
    // कुछ PDF में पाठ पन्ने की सीमा से नीचे बह जाता है और सामान्य render
    // में चुपचाप कट जाता है. transform वही रखकर canvas को नीचे से लंबा कर
    // देने पर वह बहा हुआ हिस्सा भी दिख जाता है — ?extra=1200 से माँगिए.
    cv.height = vp.height + ${extra} + ${up};
    const ctx = ctx0(cv);
    document.getElementById('c').appendChild(cv);
    // ?up= से पन्ने के ऊपर बहा हुआ हिस्सा दिखता है, ?extra= से नीचे वाला.
    ctx.translate(0, ${up});
    await p.render({ canvasContext: ctx, viewport: vp }).promise;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
  }
  document.body.dataset.done = '1';
})();
</script></body></html>`;

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');

  // कच्ची PDF — इसे केवल pdf.js माँगता है, ब्राउज़र सीधे नहीं खोलता.
  if (u.pathname.startsWith('/raw/')) {
    const f = path.join(DIR, path.basename(decodeURIComponent(u.pathname.slice(5))));
    if (!fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': 'application/pdf' });
    return fs.createReadStream(f).pipe(res);
  }

  const file = path.basename(decodeURIComponent(u.pathname.slice(1)));
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });

  if (!file || !fs.existsSync(path.join(DIR, file))) {
    return res.end(fs.readdirSync(DIR)
      .filter((f) => f.toLowerCase().endsWith('.pdf'))
      .map((f) => `<a href="/${encodeURIComponent(f)}?from=1&to=1">${f}</a>`)
      .join('<br>'));
  }

  res.end(viewer(
    file,
    Number(u.searchParams.get('from') || 1),
    Number(u.searchParams.get('to') || 1),
    Number(u.searchParams.get('scale') || 1.7),
    Number(u.searchParams.get('extra') || 0),
    Number(u.searchParams.get('up') || 0),
  ));
}).listen(PORT, () => console.log(`pdf server: http://localhost:${PORT}`));
