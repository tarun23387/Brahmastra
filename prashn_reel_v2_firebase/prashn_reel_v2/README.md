# प्रश्न रील v2 — UPPCS Pre & RO/ARO

रील की तरह सिर्फ़ **स्क्रॉल** करके प्रश्न हल कीजिए। कोई फ़िल्टर नहीं, कोई बटन नहीं — ऊपर-नीचे स्वाइप, बस।

* **150 प्रश्न** ऐप में बंडल — जिनमें **60 करेंट अफेयर्स**
* Firebase (Firestore) से जुड़कर हर हफ़्ते **नए प्रश्न** आते रहेंगे
* 15 दिन बाद पुराने साप्ताहिक प्रश्न अपने आप हट जाएँगे
* इंटरनेट न हो तो भी ऐप चलेगा (लोकल कैश + बंडल प्रश्न)
* **रीसेट** — सिर्फ़ उत्तर मिटते हैं, प्रश्न वहीं रहते हैं, दोबारा विकल्प चुन सकते हैं

| विषय | प्रश्न |
|---|---|
| करेंट अफेयर्स | 60 |
| इतिहास | 15 |
| सामान्य हिंदी (RO/ARO) | 15 |
| राजव्यवस्था | 14 |
| भूगोल | 13 |
| विज्ञान व पर्यावरण | 12 |
| यूपी विशेष | 11 |
| अर्थव्यवस्था व कृषि | 10 |

---

## भाग 1 — APK बनाइए (Firebase के बिना भी चलेगा)

```bash
cd prashn_reel_v2
flutter create --platforms=android --org com.prashnreel .
flutter pub get
flutter build apk --release
```

APK → `build/app/outputs/flutter-apk/app-release.apk`

इस चरण पर ऐप बंडल किए 150 प्रश्नों के साथ चलेगा (हेडर में **ऑफ़लाइन** दिखेगा)।

---

## भाग 2 — Firebase जोड़िए

### Step 1 — प्रोजेक्ट बनाएँ

1. [console.firebase.google.com](https://console.firebase.google.com) → **Add project**
2. नाम: `prashn-reel` → Google Analytics बंद कर सकते हैं
3. बाएँ मेन्यू → **Firestore Database** → **Create database** → **Production mode** → location `asia-south1` (मुंबई)

### Step 2 — Android ऐप रजिस्टर करें

1. प्रोजेक्ट होम पर Android आइकन दबाएँ
2. **Android package name:** `com.prashnreel.prashn_reel`
   (यह वही होना चाहिए जो `android/app/build.gradle` में `applicationId` है)
3. `google-services.json` डाउनलोड करके **`android/app/google-services.json`** में रखें
4. `android/settings.gradle` के `plugins { }` ब्लॉक में जोड़ें:
   ```gradle
   id "com.google.gms.google-services" version "4.4.2" apply false
   ```
5. `android/app/build.gradle` के `plugins { }` ब्लॉक में जोड़ें:
   ```gradle
   id "com.google.gms.google-services"
   ```

अब `flutter build apk --release` दोबारा चलाएँ — हेडर में **लाइव** दिखने लगेगा।

> यही सब कुछ `flutterfire configure` कमांड अपने आप भी कर देता है।

### Step 3 — 150 प्रश्न Firestore में भेजें

1. Firebase Console → ⚙️ **Project settings → Service accounts → Generate new private key**
2. डाउनलोड हुई फ़ाइल को `firebase/seed/serviceAccountKey.json` नाम से रखें
3. फिर:

```bash
cd firebase/seed
npm install
npm run upload
```

आउटपुट: `✅ Ho gaya — 150 prashn 'questions' collection me.`

### Step 4 — नियम लगाएँ

```bash
cd firebase
firebase login
firebase use --add          # अपना project चुनें
firebase deploy --only firestore:rules
```

नियम: कोई भी पढ़ सकता है, कोई ऐप से लिख नहीं सकता (लिखने का काम सिर्फ़ seed script और Cloud Functions करते हैं)।

---

## भाग 3 — हर हफ़्ते नए प्रश्न (Cloud Functions)

### इसके लिए क्या चाहिए

| चीज़ | क्यों |
|---|---|
| Firebase **Blaze** plan | फ़्री plan से function बाहर इंटरनेट कॉल नहीं कर सकता |
| **Anthropic API key** | प्रश्न बनाने और वेब सर्च के लिए ([console.anthropic.com](https://console.anthropic.com)) |

> मुझे कोई credential भेजने की ज़रूरत नहीं — key सीधे आप अपने Firebase प्रोजेक्ट के secret में डालेंगे, वह कहीं और नहीं जाती।

### सेट करें

```bash
cd firebase/functions
npm install

cd ..
firebase functions:secrets:set ANTHROPIC_API_KEY   # key पेस्ट करें
firebase functions:secrets:set ADMIN_TOKEN         # कोई भी लंबा पासवर्ड

firebase deploy --only functions
```

### क्या-क्या चलेगा

| फ़ंक्शन | कब | काम |
|---|---|---|
| `addWeeklyQuestions` | हर सोमवार 5:30 AM IST | वेब सर्च से **15 करेंट अफेयर्स + 15 सामान्य अध्ययन** प्रश्न बनाकर जोड़ता है |
| `cleanupOldQuestions` | रोज़ 3:00 AM IST | 15 दिन पुराने साप्ताहिक प्रश्न हटाता है |
| `runWeeklyNow` | हाथ से | टेस्ट के लिए — `https://<region>-<project>.cloudfunctions.net/runWeeklyNow?token=ADMIN_TOKEN` |

**150 core प्रश्न कभी नहीं हटेंगे।** उनमें `expiresAt` फ़ील्ड होती ही नहीं, और cleanup सिर्फ़ उसी फ़ील्ड वाले docs देखता है।

### प्रश्न कैसे बनते हैं

`firebase/functions/index.js` में हिंदी प्रॉम्प्ट है, जो मॉडल से कहता है:

* पिछले 10 दिनों की ख़बरें `web_search` से खोजो
* वही चुनो जिनके परीक्षा में आने की संभावना सबसे ज़्यादा है (योजना का नाम, मंत्रालय, स्थान, पहला/सबसे बड़ा जैसे तथ्य)
* कम से कम 6 प्रश्न उत्तर प्रदेश से जुड़े हों
* कठिनाई मध्यम, भाषा शुद्ध हिंदी, व्याख्या में एक अतिरिक्त तथ्य

फिर कोड ख़ुद जाँचता है — 4 विकल्प हैं या नहीं, answer 0–3 में है या नहीं, विकल्प दोहरे तो नहीं, और वही प्रश्न पहले से तो नहीं है।

**बदलना चाहें:** `index.js` में `WEEKLY_PLAN` (कितने प्रश्न), `LIFETIME_DAYS` (15 दिन), और `schedule` (सोमवार) — तीनों ऊपर ही दिए हैं।

> ⚠️ AI से बने प्रश्न कभी-कभी ग़लत हो सकते हैं। हफ़्ते में एक बार Firestore में नए प्रश्नों पर नज़र डाल लेना अच्छा रहेगा — ग़लत लगे तो doc delete कर दें।

---

## हाथ से प्रश्न जोड़ना

`firebase/seed/questions.json` में सूची के अंत में जोड़ें:

```json
{
  "id": "seed-151",
  "subject": "ca",
  "question": "प्रश्न?",
  "options": ["अ", "ब", "स", "द"],
  "answer": 2,
  "explanation": "व्याख्या।",
  "difficulty": "moderate",
  "source": "seed"
}
```

फिर:

```bash
python3 tools/gen_seed.py                    # ऐप का बंडल अपडेट
cd firebase/seed && npm run upload           # Firestore अपडेट
```

`subject` इनमें से कोई एक: `itihas` · `polity` · `bhugol` · `arth` · `vigyan` · `up` · `ca` · `hindi`

---

## ऐप में क्या-कहाँ है

हेडर में सिर्फ़ तीन चीज़ें हैं:

* **स्कोर** — सही / हल किए
* ☁️ **सिंक** — Firestore से नए प्रश्न लाता है
* ↻ **रीसेट** — सारे उत्तर मिटाता है (प्रश्न वहीं रहते हैं); ग़लती से दबे तो snackbar में **पूर्ववत** भी है

नीचे कोई बटन नहीं — बस स्क्रॉल। आख़िरी कार्ड पर सत्र का परिणाम और वहीं रीसेट बटन भी।

हेडर में छोटा रंगीन बिंदु बताता है प्रश्न कहाँ से आए:
🟢 **लाइव** (Firestore) · 🟠 **सेव** (लोकल कैश) · ⚪ **ऑफ़लाइन** (बंडल 150)

## फ़ाइलें

```
lib/
  main.dart              ऐप शुरू, Firebase init (वैकल्पिक)
  models.dart            Question मॉडल, विषय व रंग
  repository.dart        Firestore → कैश → सीड, और उत्तर सेव
  home_page.dart         हेडर, रील (PageView), रीसेट, परिणाम
  question_card.dart     प्रश्न कार्ड
  data/seed_questions.dart   150 बंडल प्रश्न (generated)

firebase/
  seed/questions.json    असली सोर्स — यहीं प्रश्न जोड़ें
  seed/upload.js         Firestore में भेजने की स्क्रिप्ट
  functions/index.js     साप्ताहिक जोड़ना + 15 दिन की सफ़ाई
  firestore.rules        पढ़ना खुला, लिखना बंद

tools/gen_seed.py        JSON → Dart
```

## करेंट अफेयर्स के बारे में

बंडल किए 60 करेंट अफेयर्स प्रश्न अगस्त 2026 तक की जानकारी पर आधारित हैं — UP बजट 2026-27, जेवर एयरपोर्ट, लखनऊ-कानपुर एक्सप्रेसवे, ODOC, पद्म पुरस्कार 2026, CWG 2026/2030, T20 विश्व कप 2026 आदि। Cloud Function लगने के बाद हर सोमवार इनमें नए जुड़ते रहेंगे।
