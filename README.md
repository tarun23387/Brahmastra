# ब्रह्मास्त्र — UPPCS · RO/ARO · UP PET

रील की तरह सिर्फ़ **स्क्रॉल** करके प्रश्न हल कीजिए। कोई फ़िल्टर नहीं, कोई बटन नहीं — ऊपर-नीचे स्वाइप, बस।

* **271 प्रश्न** — तीनों परीक्षाओं में चलते हैं — जिनमें **60 करेंट अफेयर्स**
* Firebase (Firestore) से जुड़कर हर हफ़्ते **नए प्रश्न** आते रहेंगे
* 15 दिन बाद पुराने साप्ताहिक प्रश्न अपने आप हट जाएँगे
* इंटरनेट न हो तो भी ऐप चलेगा (लोकल कैश + बंडल प्रश्न)
* **रीसेट** — सिर्फ़ उत्तर मिटते हैं, प्रश्न वहीं रहते हैं, दोबारा विकल्प चुन सकते हैं

| विषय | प्रश्न |
|---|---|
| इतिहास | 63 |
| करेंट अफेयर्स | 60 |
| भूगोल | 35 |
| राजव्यवस्था | 35 |
| विज्ञान व पर्यावरण | 27 |
| यूपी विशेष | 21 |
| अर्थव्यवस्था व कृषि | 15 |
| सामान्य हिंदी (RO/ARO) | 15 |

---

## भाग 1 — APK बनाइए (Firebase के बिना भी चलेगा)

```bash
cd prashn_reel_v2
flutter create --platforms=android --org com.brahmastra .
flutter pub get
flutter build apk --release
```

APK → `build/app/outputs/flutter-apk/app-release.apk`

इस चरण पर ऐप बंडल किए प्रश्नों के साथ चलेगा (हेडर में **ऑफ़लाइन** दिखेगा)।

---

## भाग 2 — Firebase जोड़िए

### Step 1 — प्रोजेक्ट बनाएँ

1. [console.firebase.google.com](https://console.firebase.google.com) → **Add project**
2. नाम: `prashn-reel` → Google Analytics बंद कर सकते हैं
3. बाएँ मेन्यू → **Firestore Database** → **Create database** → **Production mode** → location `asia-south1` (मुंबई)

### Step 2 — Android ऐप रजिस्टर करें

1. प्रोजेक्ट होम पर Android आइकन दबाएँ
2. **Android package name:** `com.brahmastra.app`
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

### Step 3 — 271 प्रश्न Firestore में भेजें

1. Firebase Console → ⚙️ **Project settings → Service accounts → Generate new private key**
2. डाउनलोड हुई फ़ाइल को `firebase/seed/serviceAccountKey.json` नाम से रखें
3. फिर:

```bash
cd firebase/seed
npm install
npm run upload
```

आउटपुट: `✅ Ho gaya — 271 prashn 'questions' collection me.`

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

**271 core प्रश्न कभी नहीं हटेंगे।** उनमें `expiresAt` फ़ील्ड होती ही नहीं, और cleanup सिर्फ़ उसी फ़ील्ड वाले docs देखता है।

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
🟢 **लाइव** (Firestore) · 🟠 **सेव** (लोकल कैश) · ⚪ **ऑफ़लाइन** (बंडल)

## फ़ाइलें

```
lib/
  main.dart              ऐप शुरू, Firebase init (वैकल्पिक)
  models.dart            Question मॉडल, विषय व रंग
  repository.dart        Firestore → कैश → सीड, और उत्तर सेव
  home_page.dart         हेडर, रील (PageView), रीसेट, परिणाम
  question_card.dart     प्रश्न कार्ड
  data/seed_questions.dart   बंडल प्रश्न (generated)

firebase/
  seed/questions.json    असली सोर्स — यहीं प्रश्न जोड़ें
  seed/upload.js         Firestore में भेजने की स्क्रिप्ट
  functions/index.js     साप्ताहिक जोड़ना + 15 दिन की सफ़ाई
  firestore.rules        पढ़ना खुला, लिखना बंद

tools/gen_seed.py        JSON → Dart
```

## करेंट अफेयर्स के बारे में

बंडल किए 60 करेंट अफेयर्स प्रश्न अगस्त 2026 तक की जानकारी पर आधारित हैं — UP बजट 2026-27, जेवर एयरपोर्ट, लखनऊ-कानपुर एक्सप्रेसवे, ODOC, पद्म पुरस्कार 2026, CWG 2026/2030, T20 विश्व कप 2026 आदि। Cloud Function लगने के बाद हर सोमवार इनमें नए जुड़ते रहेंगे।

---

## एडमिन के औज़ार

सब `firebase/admin/` फ़ोल्डर से चलते हैं। पहली बार `npm install` कर लीजिए।

### प्रश्न जोड़ना

```bash
node import.js mere-prashn.json            # सिर्फ़ जाँच
node import.js mere-prashn.json --commit   # असल में डालना
```

एक साथ सैकड़ों प्रश्न चढ़ जाते हैं। हर प्रश्न की जाँच होती है — 4 विकल्प, `answer` 0–3, विषय सही, व्याख्या भरी हो। **एक भी ख़राब हुआ तो पूरी फ़ाइल रुक जाती है**, ताकि आधा-अधूरा डेटा न चढ़े। वही प्रश्न पहले से हो तो छोड़ देता है।

विषय से परीक्षा अपने आप लग जाती है — `hindi` डालिए तो `roaro-hindi`, `pet-main`, `uppcs-csat` तीनों जुड़ेंगे।

एक-दो प्रश्न बदलने हों तो वेब पैनल भी है:

```bash
npm start        # फिर browser में  http://localhost:4000
```

### सदस्यता

```bash
node subscriptions.js list
node subscriptions.js create --name "राम कुमार" --phone 9876543210 --exams roaro,uppcs --months 1
node subscriptions.js extend ro2601 --months 1
node subscriptions.js disable ro2601
node subscriptions.js reset-password ro2601
```

`create` आईडी और पासवर्ड बनाकर एक बार दिखाता है — वही उपयोगकर्ता को भेजना है। **पासवर्ड दोबारा नहीं दिखेगा**, Firebase उसे hash करके रखता है।

### भुगतान की जानकारी

```bash
node subscriptions.js contact                          # अभी क्या लगा है
node subscriptions.js contact --upi "aap@upi" --phone 9876543210 --price 100
```

यह ऐप में लिखी नहीं है — Firestore से आती है, इसलिए बदलने पर नया APK बाँटने की ज़रूरत नहीं।

### मुफ़्त नमूना

```bash
node subscriptions.js free-sample --commit
```

25 प्रश्न चुनकर उन पर `free: true` लगा देता है — बिना लॉगिन वालों को वही दिखते हैं।

---

## परीक्षा और प्रश्नपत्र

एक ही प्रश्न कई परीक्षाओं में चलता है, इसलिए हर प्रश्न पर `exams` और `papers` दोनों सूचियाँ लगती हैं।

| परीक्षा | प्रश्नपत्र | प्रश्न | ऋणात्मक |
|---|---|---|---|
| UPPCS | सामान्य अध्ययन I | 150 | 1/3 |
| UPPCS | सी-सैट (क्वालिफाइंग 33%) | 100 | 1/3 |
| RO/ARO | सामान्य अध्ययन | 140 | 1/3 |
| RO/ARO | सामान्य हिंदी | 60 | 1/3 |
| UP PET | एक ही पेपर, 15 खंड | 100 | 1/4 |

सूची `firebase/shared/exams.json` और `lib/exams.dart` में है — **एक बदलें तो दूसरी भी बदलनी होगी।**

### अभी कहाँ कमी है

| प्रश्नपत्र | हमारे पास | पेपर में आते हैं |
|---|---|---|
| UPPCS सामान्य अध्ययन I | 256 | 150 |
| RO/ARO सामान्य अध्ययन | 256 | 140 |
| **RO/ARO सामान्य हिंदी** | **15** | **60** |
| UPPCS सी-सैट | 15 | 100 |

**सबसे ज़रूरी काम — RO/ARO की सामान्य हिंदी।** वह पूरे RO/ARO का 30% है और उसमें सिर्फ़ 15 प्रश्न हैं।

PET में गणित, English, तर्कशक्ति, गद्यांश, ग्राफ़ और सारणी — यानी 100 में से 45 अंक — पर अभी एक भी प्रश्न नहीं है। ग्राफ़/सारणी वाले प्रश्न मौजूदा ढाँचे (प्रश्न + 4 विकल्प) में आते ही नहीं, उनके लिए अलग रूप बनाना पड़ेगा।

---

## बंडल किए प्रश्न (offline)

APK के अंदर सिर्फ़ **मुफ़्त नमूने वाले 25 प्रश्न** रहते हैं — बाक़ी नहीं।

वजह: APK के भीतर जो कुछ हो, उसे निकाला जा सकता है। पहले पूरे 271 प्रश्न बंडल थे, यानी कोई भी इंटरनेट बंद करके सब देख लेता और सदस्यता का कोई मतलब ही न रहता।

बाक़ी प्रश्न Firestore से आते हैं, और **पहली बार सिंक होने के बाद कैश से बिना इंटरनेट भी चलते हैं।** यानी सदस्य को सिर्फ़ एक बार जुड़ना पड़ता है।

मुफ़्त नमूना बदलें तो बंडल भी दोबारा बनाइए, वरना दोनों अलग-अलग बातें कहेंगे:

```bash
cd firebase/admin && node subscriptions.js free-sample --commit && node gen-seed.js --write
```

फिर `flutter build apk --release --split-per-abi`।

> `tools/gen_seed.py` अब इस्तेमाल में नहीं है — वह पुरानी `questions.json` से पूरा बंडल बनाती थी। उसकी जगह `firebase/admin/gen-seed.js` है, जो सीधे Firestore से सिर्फ़ मुफ़्त प्रश्न लेती है।
