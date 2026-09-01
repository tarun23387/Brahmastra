/**
 * प्रश्न रील — Cloud Functions
 *
 * 1. addWeeklyQuestions  : har hafte (Somvaar 5:30 AM IST) internet se
 *                          current affairs + baaki subjects ke naye prashn banata hai.
 * 2. cleanupOldQuestions : roz chalta hai, 15 din purane weekly prashn hata deta hai.
 * 3. runWeeklyNow        : manual trigger (testing ke liye), token se protected.
 *
 * Zaroori:
 *   - Firebase Blaze (pay-as-you-go) plan, kyunki functions ko bahar internet
 *     call karni hoti hai.
 *   - Anthropic API key secret me:  firebase functions:secrets:set ANTHROPIC_API_KEY
 *   - Manual trigger ke liye:       firebase functions:secrets:set ADMIN_TOKEN
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
const ADMIN_TOKEN = defineSecret('ADMIN_TOKEN');

const COLLECTION = 'questions';
const LIFETIME_DAYS = 15;      // itne din baad weekly prashn hat jate hain
const MODEL = 'claude-sonnet-5';

// Har hafte kitne prashn, kis vishay ke
const WEEKLY_PLAN = [
  { subject: 'ca', count: 15, label: 'करेंट अफेयर्स' },
  { subject: 'mixed', count: 15, label: 'सामान्य अध्ययन (मिश्रित)' },
];

const SUBJECT_IDS = ['itihas', 'polity', 'bhugol', 'arth', 'vigyan', 'up', 'ca', 'hindi'];

/* ────────────────────────── prompts ────────────────────────── */

function buildPrompt(plan) {
  const today = new Date().toISOString().slice(0, 10);

  if (plan.subject === 'ca') {
    return `आज की तारीख़ ${today} है।

तुम UPPSC PCS (प्रारंभिक) और UP RO/ARO परीक्षा के लिए प्रश्न बनाने वाले अनुभवी विशेषज्ञ हो।

काम: web_search टूल से पिछले 10 दिनों की ख़बरें खोजो और ${plan.count} बहुविकल्पीय प्रश्न बनाओ।

खोज के विषय (हर एक पर अलग-अलग search करो):
- उत्तर प्रदेश सरकार की नई योजनाएँ, उद्घाटन, नियुक्तियाँ, सम्मेलन
- केंद्र सरकार की नई योजनाएँ, नीतियाँ, कैबिनेट निर्णय
- रिपोर्ट, सूचकांक और रैंकिंग में भारत/उत्तर प्रदेश की स्थिति
- पुरस्कार, सम्मान, महत्वपूर्ण नियुक्तियाँ
- खेल, रक्षा, अंतरिक्ष और विज्ञान
- अंतरराष्ट्रीय शिखर सम्मेलन और समझौते

नियम (बहुत ज़रूरी):
1. सिर्फ़ वही तथ्य लो जो search results में स्पष्ट रूप से दिखे। अंदाज़ा मत लगाओ।
2. वही ख़बरें चुनो जिनके परीक्षा में आने की संभावना सबसे ज़्यादा है — योजना का नाम, लॉन्च करने वाला मंत्रालय, स्थान, संख्या, पहला/सबसे बड़ा जैसे तथ्य।
3. कम से कम 6 प्रश्न उत्तर प्रदेश से जुड़े हों।
4. कठिनाई स्तर मध्यम (moderate) — न बहुत आसान, न अति सूक्ष्म।
5. प्रश्न और सभी विकल्प शुद्ध हिंदी में हों।
6. चारों विकल्प विश्वसनीय लगें (गलत विकल्प भी उसी श्रेणी के हों)।
7. व्याख्या 1–2 वाक्य की हो और उसमें एक अतिरिक्त परीक्षा-उपयोगी तथ्य ज़रूर हो।
8. subject हमेशा "ca" रखो।`;
  }

  return `आज की तारीख़ ${today} है।

तुम UPPSC PCS (प्रारंभिक) और UP RO/ARO परीक्षा के लिए प्रश्न बनाने वाले अनुभवी विशेषज्ञ हो।
इन परीक्षाओं के पिछले 10 वर्षों के प्रश्नपत्रों का पैटर्न ध्यान में रखो।

काम: ${plan.count} बहुविकल्पीय प्रश्न बनाओ — इन विषयों में बाँटकर:
- itihas (इतिहास, विशेषकर उत्तर प्रदेश से जुड़ा स्वतंत्रता संग्राम, प्राचीन-मध्यकालीन) — 3
- polity (भारतीय संविधान, अनुच्छेद, संशोधन) — 3
- bhugol (भारत व उत्तर प्रदेश का भूगोल, नदियाँ, जिले, परियोजनाएँ) — 2
- arth (अर्थव्यवस्था, कृषि, योजनाएँ) — 2
- vigyan (सामान्य विज्ञान, पर्यावरण, पारिस्थितिकी) — 2
- up (उत्तर प्रदेश विशेष — संस्कृति, लोकनृत्य, ODOP, संस्थाएँ) — 2
- hindi (सामान्य हिंदी — संधि, समास, अलंकार, तत्सम-तद्भव, मुहावरे — RO/ARO के लिए) — 1

नियम:
1. वही टॉपिक चुनो जो इन परीक्षाओं में बार-बार पूछे जाते हैं और जिनके दोबारा आने की संभावना सबसे ज़्यादा है।
2. ऐसे तथ्य चुनो जो निश्चित और सत्यापित हों — विवादित या बदलते आँकड़े मत लो।
3. कठिनाई स्तर मध्यम (moderate)।
4. ज़रूरत लगे तो web_search से तथ्य जाँच लो।
5. प्रश्न और विकल्प शुद्ध हिंदी में।
6. व्याख्या 1–2 वाक्य, साथ में एक जुड़ा हुआ अतिरिक्त तथ्य।`;
}

const OUTPUT_RULE = `

आउटपुट सिर्फ़ एक JSON array हो — कोई भूमिका नहीं, कोई markdown fence नहीं:
[
  {
    "subject": "ca",
    "question": "प्रश्न?",
    "options": ["विकल्प अ", "विकल्प ब", "विकल्प स", "विकल्प द"],
    "answer": 2,
    "explanation": "व्याख्या।"
  }
]
"answer" सही विकल्प का index है (0 से 3)। हर प्रश्न में ठीक 4 विकल्प हों।`;

/* ────────────────────────── Anthropic call ────────────────────────── */

async function generate(plan, apiKey) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 8000,
      tools: [{ type: 'web_search_20250305', name: 'web_search', max_uses: 12 }],
      messages: [{ role: 'user', content: buildPrompt(plan) + OUTPUT_RULE }],
    }),
  });

  if (!res.ok) {
    throw new Error(`Anthropic API ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const text = (data.content || [])
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('\n');

  const start = text.indexOf('[');
  const end = text.lastIndexOf(']');
  if (start < 0 || end <= start) {
    throw new Error('Response me JSON array nahi mila');
  }

  return JSON.parse(text.slice(start, end + 1));
}

/* ────────────────────────── validation ────────────────────────── */

function isValid(q) {
  return (
    q &&
    typeof q.question === 'string' &&
    q.question.trim().length > 10 &&
    Array.isArray(q.options) &&
    q.options.length === 4 &&
    q.options.every((o) => typeof o === 'string' && o.trim().length > 0) &&
    new Set(q.options.map((o) => o.trim())).size === 4 &&
    Number.isInteger(q.answer) &&
    q.answer >= 0 &&
    q.answer <= 3 &&
    typeof q.explanation === 'string' &&
    q.explanation.trim().length > 5
  );
}

async function alreadyExists(question) {
  const snap = await db
    .collection(COLLECTION)
    .where('question', '==', question.trim())
    .limit(1)
    .get();
  return !snap.empty;
}

/* ────────────────────────── main job ────────────────────────── */

async function addWeekly(apiKey) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + LIFETIME_DAYS * 24 * 60 * 60 * 1000);
  const stamp = now.toISOString().slice(0, 10).replace(/-/g, '');

  let added = 0;
  let skipped = 0;

  for (const plan of WEEKLY_PLAN) {
    let items;
    try {
      items = await generate(plan, apiKey);
    } catch (e) {
      logger.error(`${plan.label} generate fail:`, e.message);
      continue;
    }

    let idx = 0;
    for (const q of items) {
      if (!isValid(q)) {
        skipped++;
        continue;
      }
      if (await alreadyExists(q.question)) {
        skipped++;
        continue;
      }

      const subject = SUBJECT_IDS.includes(q.subject) ? q.subject : 'ca';
      const id = `wk-${stamp}-${plan.subject}-${idx++}`;

      await db.collection(COLLECTION).doc(id).set({
        subject,
        question: q.question.trim(),
        options: q.options.map((o) => o.trim()),
        answer: q.answer,
        explanation: q.explanation.trim(),
        difficulty: 'moderate',
        source: 'weekly',
        createdAt: admin.firestore.Timestamp.fromDate(now),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      });
      added++;
    }
  }

  logger.info(`Weekly done — added: ${added}, skipped: ${skipped}`);
  if (added > 0) await bumpManifest();
  return { added, skipped };
}

/* ────────────────────────── cleanup ────────────────────────── */

async function cleanup() {
  const now = admin.firestore.Timestamp.now();

  // NOTE: seed prashno me `expiresAt` field hoti hi nahi,
  // aur Firestore inequality query un docs ko chhod deti hai
  // jinme field maujood nahi — isliye 150 core prashn surakshit hain.
  const snap = await db
    .collection(COLLECTION)
    .where('expiresAt', '<', now)
    .limit(400)
    .get();

  if (snap.empty) {
    logger.info('Cleanup — kuch purana nahi mila');
    return 0;
  }

  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  logger.info(`Cleanup — ${snap.size} purane prashn hataye gaye`);
  await bumpManifest();
  return snap.size;
}

/* ────────────────────────── manifest ────────────────────────── */

/**
 * `config/manifest` ka version aage badhata hai.
 *
 * App ab samay se nahi, version se tay karta hai ki prashn dobara utarne
 * hain ya nahi (dekhiye lib/repository.dart). Iska matlab: naye prashn
 * daalne ke baad version badhana zaroori hai, warna woh chhatron tak
 * pahunchte hi nahi — 30 din tak nahi.
 *
 * Weekly prashno par `papers` field nahi lagti, isliye sirf `all` badhate
 * hain. Paper-wise cache tab bekaar nahi hota, aur har hafte har chhatra
 * poora paper dobara nahi utarta.
 *
 * Yeh fail ho jaye to poora weekly run fail nahi karna chahiye — prashn
 * chadh to chuke hain. Isliye error sirf log hota hai.
 */
async function bumpManifest(keys = ['all']) {
  const ref = db.collection('config').doc('manifest');
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const papers = (snap.exists && snap.data().papers) || {};
      for (const k of keys) {
        papers[k] = (typeof papers[k] === 'number' ? papers[k] : 0) + 1;
      }
      tx.set(
        ref,
        { papers, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });
    logger.info(`Manifest bump — ${keys.join(', ')}`);
  } catch (e) {
    logger.error('Manifest bump fail:', e.message);
  }
}

/* ────────────────────────── exports ────────────────────────── */

exports.addWeeklyQuestions = onSchedule(
  {
    schedule: 'every monday 05:30',
    timeZone: 'Asia/Kolkata',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async () => {
    await addWeekly(ANTHROPIC_API_KEY.value());
  }
);

exports.cleanupOldQuestions = onSchedule(
  {
    schedule: 'every day 03:00',
    timeZone: 'Asia/Kolkata',
    timeoutSeconds: 300,
  },
  async () => {
    await cleanup();
  }
);

// Testing ke liye:  https://<region>-<project>.cloudfunctions.net/runWeeklyNow?token=XXXX
exports.runWeeklyNow = onRequest(
  {
    secrets: [ANTHROPIC_API_KEY, ADMIN_TOKEN],
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (req, res) => {
    if (req.query.token !== ADMIN_TOKEN.value()) {
      res.status(403).send('forbidden');
      return;
    }
    try {
      const result = await addWeekly(ANTHROPIC_API_KEY.value());
      const removed = await cleanup();
      res.json({ ok: true, ...result, removed });
    } catch (e) {
      logger.error(e);
      res.status(500).json({ ok: false, error: e.message });
    }
  }
);
