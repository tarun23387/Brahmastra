/**
 * JSON फ़ाइल से एक साथ बहुत सारे प्रश्न चढ़ाने के लिए.
 *
 *   node import.js prashn.json              # सिर्फ़ जाँचता है, कुछ नहीं लिखता
 *   node import.js prashn.json --commit     # असल में Firestore में डालता है
 *
 * बिना --commit के डेटाबेस को छूता तक नहीं — पहले रिपोर्ट देख लीजिए.
 *
 * फ़ाइल का रूप — एक array, हर प्रश्न ऐसा:
 *
 * [
 *   {
 *     "subject": "itihas",
 *     "question": "प्रश्न?",
 *     "options": ["अ", "ब", "स", "द"],
 *     "answer": 1,
 *     "explanation": "व्याख्या।",
 *     "exams": ["roaro", "uppcs"]      // वैकल्पिक — न दें तो विषय से अपने आप लग जाएगा
 *   }
 * ]
 *
 * "id" देना ज़रूरी नहीं. न दें तो imp-0001, imp-0002 … अपने आप बनती हैं.
 * वही id दोबारा दें तो पुराना प्रश्न बदल जाएगा (duplicate नहीं बनेगा).
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COLLECTION = 'questions';

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

const SUBJECTS = shared.subjects;
const { tagsFor } = require('./taxonomy');


/* ───────────────────────── firebase ───────────────────────── */

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/* ───────────────────────── जाँच ───────────────────────── */

/**
 * एक प्रश्न की पूरी जाँच.
 *
 * ये नियम lib/models.dart के Question.fromMap से मेल खाते हैं — यानी जो
 * यहाँ पास हुआ, वह ऐप में ज़रूर दिखेगा. जो यहाँ अटका, वह ऐप में चुपचाप
 * ग़ायब हो जाता, इसलिए यहीं रोक देना बेहतर है.
 */
function check(row, index) {
  const errors = [];

  const question = String(row.question ?? '').trim();
  if (!question) errors.push('प्रश्न खाली है');

  const options = Array.isArray(row.options)
    ? row.options.map((o) => String(o ?? '').trim())
    : null;

  if (!options) {
    errors.push('options एक सूची होनी चाहिए');
  } else if (options.length !== 4) {
    errors.push(`ठीक 4 विकल्प चाहिए, मिले ${options.length}`);
  } else if (options.some((o) => !o)) {
    errors.push('कोई विकल्प खाली है');
  } else if (new Set(options).size !== 4) {
    errors.push('दो विकल्प एक जैसे हैं');
  }

  const answer = Number.isInteger(row.answer)
    ? row.answer
    : parseInt(row.answer, 10);
  if (!Number.isInteger(answer) || answer < 0 || answer > 3) {
    errors.push(`answer 0 से 3 के बीच होना चाहिए, मिला "${row.answer}"`);
  }

  const subject = String(row.subject ?? '').trim();
  if (!SUBJECTS[subject]) {
    errors.push(`विषय "${subject}" पहचाना नहीं गया`);
  }

  // व्याख्या अच्छी होती है पर हर प्रश्न में ज़रूरी नहीं — विलोम, पर्यायवाची
  // जैसे प्रश्नों में उत्तर ही व्याख्या है. इसलिए रोकते नहीं, बस गिन लेते हैं.
  const explanation = String(row.explanation ?? '').trim();

  // exams बताया हो तो पहचाना हुआ होना चाहिए.
  // न बताया हो तो taxonomy.js डिफ़ॉल्ट (RO/ARO) लगा देता है.
  if (Array.isArray(row.exams) && row.exams.length) {
    const bad = row.exams.filter((e) => !shared.exams[e]);
    if (bad.length) {
      errors.push(`अनजान परीक्षा: ${bad.join(', ')} — चलेंगी: uppcs, roaro, pet`);
    }
  }

  // सूची-मिलान वाला प्रश्न — दोनों सूचियाँ अलग रखी जाती हैं ताकि ऐप उन्हें
  // आमने-सामने सारणी में दिखा सके. `match` दिया हो तो पूरा-सही होना चाहिए,
  // अधूरा हो तो कार्ड में आधी सारणी दिखेगी — इसलिए यहीं रोक देते हैं.
  let match = null;
  if (row.match != null) {
    const m = row.match;
    const left = Array.isArray(m.left) ? m.left.map((x) => String(x).trim()) : null;
    const right = Array.isArray(m.right) ? m.right.map((x) => String(x).trim()) : null;

    if (!left || !right) {
      errors.push('match में left और right दोनों सूचियाँ चाहिए');
    } else if (left.length < 2 || right.length < 2) {
      errors.push('match की सूची में कम से कम 2 प्रविष्टियाँ चाहिए');
    } else if (left.length !== right.length) {
      errors.push(`match की दोनों सूचियाँ बराबर होनी चाहिए — ${left.length} बनाम ${right.length}`);
    } else if (left.some((x) => !x) || right.some((x) => !x)) {
      errors.push('match की कोई प्रविष्टि खाली है');
    } else {
      match = {
        // प्रश्न की पहली पंक्ति. `question` में दोनों सूचियाँ सादे पाठ में
        // भी रहती हैं ताकि पुरानी APK में प्रश्न अधूरा न दिखे — नई APK
        // ऊपर सिर्फ़ यह पंक्ति छापकर नीचे सारणी बनाती है.
        intro: String(m.intro ?? '').trim(),
        leftTitle: String(m.leftTitle ?? 'सूची-I').trim(),
        rightTitle: String(m.rightTitle ?? 'सूची-II').trim(),
        left,
        right,
      };
    }
  }

  if (errors.length) return { ok: false, line: index + 1, errors, row };

  const { exams, papers } = tagsFor(subject, row.exams);

  return {
    ok: true,
    id: row.id ? String(row.id).trim() : null,
    value: {
      subject,
      question,
      options,
      answer,
      explanation,
      exams,
      papers: papers.sort(),
      difficulty: row.difficulty || 'moderate',
      ...(match ? { match } : {}),
    },
  };
}

/** प्रश्न + विकल्प मिलाकर पहचान — सिर्फ़ प्रश्न से काम नहीं चलता. */
function dupeKey(v) {
  const opts = [...(v.options || [])].map((o) => String(o).trim()).sort();
  return String(v.question).trim() + '||' + opts.join('|');
}

/* ───────────────────────── main ───────────────────────── */

async function main() {
  const file = process.argv[2];
  const COMMIT = process.argv.includes('--commit');

  if (!file) {
    console.log(`
उपयोग:
  node import.js <file.json>            जाँचता है, कुछ नहीं बदलता
  node import.js <file.json> --commit   असल में Firestore में डालता है
`);
    process.exit(0);
  }

  if (!fs.existsSync(file)) {
    console.error(`❌ फ़ाइल नहीं मिली: ${file}`);
    process.exit(1);
  }

  let rows;
  try {
    rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    console.error(`❌ JSON पढ़ा नहीं जा सका: ${e.message}`);
    console.error('   अक्सर वजह — आख़िरी चीज़ के बाद कॉमा, या दोहरे quote की जगह इकहरे.');
    process.exit(1);
  }

  if (!Array.isArray(rows)) {
    console.error('❌ फ़ाइल में एक array होनी चाहिए — [ { … }, { … } ]');
    process.exit(1);
  }

  console.log(COMMIT
    ? '\n⚠️  COMMIT — Firestore में असल बदलाव होंगे.\n'
    : '\n👀 सिर्फ़ जाँच — कुछ नहीं बदलेगा. डालने के लिए --commit लगाइए.\n');
  console.log(`📄 ${rows.length} प्रश्न फ़ाइल में मिले.\n`);

  // ── जाँच ──
  const good = [];
  const bad = [];
  const seen = new Map();

  rows.forEach((row, i) => {
    const r = check(row, i);
    if (!r.ok) {
      bad.push(r);
      return;
    }
    // एक ही फ़ाइल में वही प्रश्न दो बार?
    //
    // NOTE: सिर्फ़ प्रश्न का पाठ देखना काफ़ी नहीं. "शुद्ध वाक्य है –" जैसे
    // प्रश्न परीक्षा में बार-बार आते हैं, हर बार अलग विकल्पों के साथ —
    // वे दोहरे नहीं हैं. इसलिए विकल्प भी मिलाते हैं.
    const key = dupeKey(r.value);
    if (seen.has(key)) {
      bad.push({
        line: i + 1,
        errors: [`यही प्रश्न इसी फ़ाइल में लाइन ${seen.get(key)} पर भी है`],
      });
      return;
    }
    seen.set(key, i + 1);
    good.push(r);
  });

  // ── Firestore में पहले से मौजूद? ──
  const existingSnap = await db.collection(COLLECTION).get();
  const byQuestion = new Map();
  const usedIds = new Set();
  let maxImp = 0;

  for (const d of existingSnap.docs) {
    byQuestion.set(dupeKey(d.data()), d.id);
    usedIds.add(d.id);
    const m = /^imp-(\d+)$/.exec(d.id);
    if (m) maxImp = Math.max(maxImp, parseInt(m[1], 10));
  }

  const toAdd = [];
  const toUpdate = [];
  const skipped = [];

  for (const r of good) {
    const existingId = byQuestion.get(dupeKey(r.value));

    if (r.id) {
      // id दी गई है — जान-बूझकर बदलना चाहते हैं
      (usedIds.has(r.id) ? toUpdate : toAdd).push({ ...r, id: r.id });
    } else if (existingId) {
      skipped.push({ id: existingId, question: r.value.question });
    } else {
      maxImp++;
      // NOTE: फैलाव पहले, id बाद में — उलटा करने पर r.id (null) ऊपर से आकर
      // बनाई हुई id मिटा देता था, और commit "documentPath" पर गिर जाता था.
      toAdd.push({ ...r, id: `imp-${String(maxImp).padStart(4, "0")}` });
    }
  }

  /* ── रिपोर्ट ── */

  if (bad.length) {
    console.log(`❌ ${bad.length} प्रश्न में गड़बड़ी:\n`);
    for (const b of bad.slice(0, 20)) {
      console.log(`   लाइन ${b.line}: ${b.errors.join(' · ')}`);
      if (b.row?.question) {
        console.log(`      "${String(b.row.question).slice(0, 55)}…"`);
      }
    }
    if (bad.length > 20) console.log(`   … और ${bad.length - 20}\n`);
    else console.log('');
  }

  if (skipped.length) {
    console.log(`⏭️  ${skipped.length} प्रश्न पहले से मौजूद हैं — छोड़ दिए.`);
    for (const s of skipped.slice(0, 5)) {
      console.log(`   ${s.id}: "${s.question.slice(0, 50)}…"`);
    }
    if (skipped.length > 5) console.log(`   … और ${skipped.length - 5}`);
    console.log('');
  }

  console.log(`✅ ${toAdd.length} नए जुड़ेंगे`);
  if (toUpdate.length) console.log(`♻️  ${toUpdate.length} पुराने बदलेंगे`);

  const noExp = [...toAdd, ...toUpdate].filter((r) => !r.value.explanation);
  if (noExp.length) {
    console.log(`ℹ️  ${noExp.length} में व्याख्या नहीं है — चलेंगे, पर जोड़ देना बेहतर है.`);
  }

  // विषय-वार गिनती
  const bySubject = {};
  const byPaper = {};
  for (const r of [...toAdd, ...toUpdate]) {
    bySubject[r.value.subject] = (bySubject[r.value.subject] || 0) + 1;
    for (const p of r.value.papers) byPaper[p] = (byPaper[p] || 0) + 1;
  }

  if (Object.keys(bySubject).length) {
    console.log('\nविषय-वार:');
    for (const [s, n] of Object.entries(bySubject).sort((a, b) => b[1] - a[1])) {
      console.log(`   ${(SUBJECTS[s]?.label || s).padEnd(22)} ${n}`);
    }
    console.log('\nप्रश्नपत्र-वार:');
    for (const [p, n] of Object.entries(byPaper).sort((a, b) => b[1] - a[1])) {
      console.log(`   ${p.padEnd(14)} ${n}`);
    }
  }

  if (!COMMIT) {
    console.log('\n👀 जाँच ही थी — Firestore में कुछ नहीं गया.');
    console.log('   डालने के लिए:  node import.js ' + file + ' --commit\n');
    process.exit(bad.length ? 1 : 0);
  }

  if (bad.length) {
    console.log('\n⛔ पहले गड़बड़ी ठीक कीजिए — तब तक कुछ नहीं डाला गया.');
    console.log('   (एक भी ख़राब प्रश्न हो तो पूरी फ़ाइल रोक देते हैं,');
    console.log('    ताकि आधा-अधूरा डेटा न चढ़े.)\n');
    process.exit(1);
  }

  /* ── असल में लिखना ── */

  const all = [...toAdd, ...toUpdate];
  let batch = db.batch();
  let pending = 0;
  let done = 0;

  for (const r of all) {
    const ref = db.collection(COLLECTION).doc(r.id);
    const payload = {
      ...r.value,
      source: 'import',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // NOTE: expiresAt जान-बूझकर नहीं लगती — cleanup function सिर्फ़ उसी
      // field वाले docs हटाता है, इसलिए ये प्रश्न कभी अपने आप नहीं मिटेंगे.
    };
    if (!usedIds.has(r.id)) {
      payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    batch.set(ref, payload, { merge: true });
    pending++;
    done++;

    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
      console.log(`   … ${done}/${all.length}`);
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`\n✅ हो गया — ${done} प्रश्न '${COLLECTION}' में.`);
  console.log('   ऐप में सिंक बटन दबाकर देख सकते हैं.\n');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e);
  process.exit(1);
});
