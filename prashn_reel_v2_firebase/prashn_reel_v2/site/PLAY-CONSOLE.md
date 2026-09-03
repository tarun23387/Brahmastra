# Play Console — क्या भरना है

ब्रह्मास्त्र · `com.brahmastra.app` · 27 अगस्त 2026

Console के form भरते वक़्त यही देखकर भरिए। जो जवाब यहाँ लिखे हैं वे ऐप के असली
कोड से मिलाकर तय किए गए हैं — अंदाज़े से नहीं।

---

## 0. पन्ने host हो चुके हैं ✅

Play बिना public privacy policy URL के listing submit नहीं करने देता।
ये पन्ने **27 अगस्त 2026** को Firebase Hosting पर चढ़ चुके हैं — वही project
जो ऐप इस्तेमाल करता है (`exampreparation-bc34c`), Spark plan पर मुफ़्त:

| क्या | URL |
|---|---|
| निजता नीति | `https://exampreparation-bc34c.web.app/privacy.html` |
| खाता मिटवाना | `https://exampreparation-bc34c.web.app/account-deletion.html` |
| स्रोत और अस्वीकरण | `https://exampreparation-bc34c.web.app/sources.html` |

> `sources.html` **2 सितंबर 2026** को जुड़ा — Play की *Misleading Claims*
> रोक का जवाब। उस पर अस्वीकरण ("यह सरकारी ऐप नहीं है") और हर सरकारी
> जानकारी का आधिकारिक स्रोत-लिंक है। अपील में यही URL देना है।
> बदलाव के बाद deploy करना न भूलिए, वरना अपील में दिया लिंक 404 देगा।

चारों HTML `firebase/public/` में रहती हैं — Hosting का public folder
`firebase.json` वाले फ़ोल्डर के **अंदर** होना ज़रूरी है, बाहर (`../site`)
रखने पर deploy साफ़ मना कर देता है। इसीलिए `PLAY-CONSOLE.md` (यही फ़ाइल)
`site/` में अलग पड़ी है — वह published पेड़ से बाहर है, इसलिए अंदर की
जानकारी कभी public नहीं होती।

बदलाव करके दोबारा चढ़ाना हो तो `firebase/` में जाकर:

```bash
npx --yes firebase-tools deploy --only hosting
```

> ⚠️ **`--only hosting` कभी मत छोड़िए।** खाली `firebase deploy` functions
> भी चढ़ाने की कोशिश करेगा, जो Spark plan पर हो ही नहीं सकते — पूरा deploy
> वहीं फ़ेल हो जाएगा।

> ⚠️ `firebase login` **असली terminal** में ही चलता है (CMD/PowerShell window)।
> किसी non-interactive shell से चलाने पर वह browser वाला रास्ता छोड़कर
> code-paste वाले fallback पर चला जाता है और टूट जाता है।

**तीनों फ़ाइलें भरी हुई हैं** — नाम `Tarun Singh`, ईमेल `ts23387@gmail.com`,
फ़ोन `+91 8299361252` (वही जो `config/contact` में है)।

> Play Console पर डेवलपर का नाम और संपर्क ईमेल **बिल्कुल यही** रखिए —
> दोनों जगह मेल न खाएँ तो समीक्षा में सवाल उठता है।
>
> UPI आईडी इन पन्नों पर जानबूझकर कहीं नहीं है।

> बोनस: अब `npx firebase-tools deploy --only firestore:rules` भी चलता है,
> यानी rules Console में हाथ से paste करने की ज़रूरत नहीं रही।

---

## 1. App access

**जवाब:** "All functionality is available without special access"

ऐप का मुख्य हिस्सा — पूरा यूपी पीईटी — बिना लॉगिन खुला है। समीक्षक को
लॉगिन की ज़रूरत नहीं।

> अगर वे फिर भी सदस्यता वाला हिस्सा देखना चाहें तो एक test आईडी बनाकर
> "Instructions" में डाल दीजिए:
> `node subscriptions.js create --name "Play Review" --exams pet,roaro,uppcs --months 6`

---

## 2. Ads

**जवाब:** "No, my app does not contain ads"

ऐप में कोई विज्ञापन नहीं है।

> ⚠️ इससे उलझिए मत कि manifest में `AD_ID` अनुमति दिख रही है — वह
> firebase-analytics अपने साथ लाता है, विज्ञापन दिखाने के लिए नहीं। पर
> Data safety में उसे declare करना ज़रूरी है (नीचे देखिए)।

---

## 3. Content rating

Questionnaire भरिए। सब जवाब **"No"** होंगे — ऐप में हिंसा, नशा, जुआ,
यौन सामग्री, डरावनी सामग्री, उपयोगकर्ताओं की आपसी बातचीत, कुछ भी नहीं है।

Category: **Reference, News, or Educational**

नतीजा आमतौर पर: **Rated for 3+**

---

## 4. Target audience and content

- **Target age group:** 18 और उससे ऊपर
- **Appeals to children:** No

> ⚠️ 13 से कम उम्र का कोई group मत चुनिए। चुनते ही "Designed for Families"
> के सख़्त नियम लग जाएँगे — तब `AD_ID` अनुमति हटानी पड़ेगी और Analytics
> बदलना पड़ेगा।

---

## 5. Data safety — सबसे ध्यान से भरने वाला हिस्सा

पहले तीन बुनियादी जवाब:

| सवाल | जवाब |
|---|---|
| क्या ऐप डेटा इकट्ठा या साझा करता है? | **Yes** |
| क्या डेटा भेजते समय encrypt होता है? | **Yes** (Firebase सब HTTPS पर भेजता है) |
| क्या उपयोगकर्ता डेटा मिटाने की माँग कर सकता है? | **Yes** — account-deletion वाला URL दीजिए |

### जो डेटा declare करना है

**Personal info → Name**
- Collected: Yes · Shared: No
- Optional (सिर्फ़ सदस्यता वालों का)
- उद्देश्य: **Account management**

**Personal info → Phone number**
- Collected: Yes · Shared: No
- Optional
- उद्देश्य: **Account management**, **Customer support**

**Personal info → User IDs**
- Collected: Yes · Shared: No
- Required (सदस्यता वालों के लिए)
- उद्देश्य: **Account management**

**Device or other IDs**
- Collected: Yes · Shared: No
- Required
- उद्देश्य: **App functionality** (एक आईडी एक फ़ोन), **Analytics**
- 🔴 इसमें Android ID और **Advertising ID** दोनों आते हैं। Advertising ID
  छोड़ दिया तो Google अपने आप पकड़ लेता है और ऐप reject हो जाती है।

**App activity → App interactions**
- Collected: Yes · Shared: No
- Required · उद्देश्य: **Analytics**


**Location → Approximate location**
- Collected: Yes · Shared: No
- Required · उद्देश्य: **Analytics**
- Firebase Analytics IP पते से शहर/राज्य का अंदाज़ा लगाता है। ऐप ख़ुद कोई
  location अनुमति नहीं माँगता।

### जो declare **नहीं** करना (ऐप लेता ही नहीं)

**Crash logs / Diagnostics** — 31 अगस्त 2026 को जाँचा: ऐप में Crashlytics है ही
नहीं (merged manifest में एक भी entry नहीं)। पहले यहाँ ग़लती से declare करने को
लिखा था। Play अपनी तरफ़ से Android vitals में crash देखता है, पर वह ऐप का
इकट्ठा किया डेटा नहीं है।

बाक़ी जो नहीं लेना:


ईमेल पता · सटीक location (GPS) · संपर्क · फ़ोटो/वीडियो/फ़ाइलें ·
कैलेंडर · SMS/कॉल · माइक्रोफ़ोन · स्वास्थ्य · वित्तीय जानकारी ·
वेब ब्राउज़िंग

> **छात्र के उत्तर और प्रगति declare नहीं करने हैं** — वे सिर्फ़ फ़ोन में
> (SharedPreferences) रहते हैं और कभी सर्वर पर नहीं जाते। Play सिर्फ़ उसी
> डेटा का हिसाब माँगता है जो फ़ोन से बाहर जाता है।

---

## 5b. App content के बाक़ी घोषणापत्र

Console इन्हें भी माँगता है, पहले यहाँ लिखे नहीं थे। सब सीधे-सादे हैं:

| घोषणा | जवाब |
|---|---|
| News apps | **No** — यह समाचार ऐप नहीं है |
| Government apps | **No** — किसी सरकारी संस्था की ओर से नहीं है |
| Financial features | **My app doesn't have any financial features** |
| Health apps | **No** |
| Advertising ID | **Yes, my app uses advertising ID** · उद्देश्य: **Analytics** |

> 🔴 **Financial features में "No" ही रहेगा।** सदस्यता का पैसा ऐप के बाहर
> लिया जाता है और Play build में UPI का कोई ज़िक्र नहीं है, इसलिए ऐप में कोई
> वित्तीय सुविधा है ही नहीं। यहाँ कुछ और चुना तो अतिरिक्त कागज़ी जाँच लग जाएगी।

> 🔴 **Advertising ID में "Yes" ही चुनना है**, भले ऐप विज्ञापन नहीं दिखाता।
> 31 अगस्त 2026 को built AAB में जाँचा — `com.google.android.gms.permission.AD_ID`
> और AppMeasurement की services मौजूद हैं, जो Firebase अपने आप साथ लाता है।
> "No" चुना तो Google की जाँच पकड़ लेगी और release रुक जाएगी।

---

## 6. Store listing

**सारा text और सारे ग्राफ़िक्स अब एक ही जगह हैं — `play-listing/`।**
Console का Main store listing पन्ना भरते वक़्त `play-listing/LISTING.md`
खोलकर वहीं से copy-paste कीजिए। उसमें हर field की लंबाई नापी हुई है।

```
play-listing/
├── LISTING.md                      ← नाम, short + full description, बाक़ी field
├── icon-512.png                    512×512
├── feature-graphic-1024x500.png    1024×500
└── screenshots/                    चार, 1080×1920 (9:16)
```

दो बातें जो वहाँ ठीक की गईं और यहाँ ग़लत लिखी थीं:

- **App name 30 अक्षर से ज़्यादा नहीं हो सकता।** यहाँ पहले
  `ब्रह्मास्त्र — UP PET, RO/ARO प्रश्न अभ्यास` लिखा था — 43 अक्षर, Console
  में डलता ही नहीं। अब `ब्रह्मास्त्र — UP PET, RO/ARO` (29) है।
- **Full description यहाँ थी ही नहीं**, जबकि Play उसके बिना listing पूरी नहीं
  मानता। वह अब लिखी जा चुकी है (3748/4000 अक्षर)।

> ⚠️ **2 सितंबर 2026 — Misleading Claims की रोक।** Play ने ऐप इसलिए रोका कि
> वह सरकारी परीक्षाओं की जानकारी देता है, पर (क) उस जानकारी का कोई
> आधिकारिक सरकारी स्रोत-लिंक कहीं नहीं था और (ख) यह कहीं साफ़ नहीं लिखा था
> कि ऐप सरकारी नहीं है।
>
> अब description की **पहली ही पंक्ति** अस्वीकरण है (Play "read more" से
> पहले सिर्फ़ शुरू की पंक्तियाँ दिखाता है, इसलिए वहीं होना ज़रूरी था) और
> अंत में "जानकारी के आधिकारिक सरकारी स्रोत" खंड में पाँच सरकारी लिंक हैं।
> वही अस्वीकरण और वही लिंक ऐप के अंदर भी हैं — पहले पन्ने की पट्टी और
> मेन्यू का "स्रोत और अस्वीकरण" — तथा `sources.html` पर भी।
>
> तीनों में से कोई एक भी हटा तो रोक दोबारा लगेगी। नया text चढ़ाने के बाद
> **App content → Store listing** दोबारा submit करना होता है, सिर्फ़ AAB
> चढ़ाने से यह मसला बंद नहीं होता।

App bundle इस folder में नहीं है — वह `dist/Brahmastra-play-2.0.1.aab` है,
ताकि नई version बनने पर दो जगह रखी पुरानी फ़ाइल ग़लती से न चढ़ जाए।

---

## 7. Closed testing par AAB chadhana

चढ़ानी है: `dist/Brahmastra-play-2.0.1.aab` — versionName `2.0.1`,
versionCode `3`, upload key से signed.

### 7.0 सबसे पहले — keystore का backup 🔴

पहला upload होते ही `android/brahmastra-release.jks` **हमेशा के लिए** इस ऐप
की upload key बन जाती है। वह खो गई तो आप अपने ही ऐप का update कभी नहीं चढ़ा
पाएँगे — नया ऐप बनाना पड़ेगा, सारे उपयोगकर्ता छूट जाएँगे। (Google से key reset
माँगी जा सकती है, पर वह लंबा और तकलीफ़देह रास्ता है।)

फ़ाइल सिर्फ़ 2.6 KB की है और अभी **इसी मशीन पर एक ही जगह** है। upload से पहले
इन तीनों की नक़ल कहीं और रख लीजिए — pen drive, अपनी ईमेल, या password manager:

- `android/brahmastra-release.jks`
- `android/key.properties`
- उसमें लिखे तीनों password/alias (अलग से भी लिख लीजिए)

ये दोनों `.gitignore` में हैं, इसलिए किसी repo में अपने आप नहीं जाएँगी —
यानी backup आपको हाथ से ही लेना है।

### 7.1 ऐप बनाइए (पहली बार)

> 🔴 **इससे पहले account verification पूरी होनी ज़रूरी है.** 31 अगस्त 2026 को
> देखा: verification अधूरी हो तो app-list पर लिखा आता है "Complete account
> verifications to create new apps" और **Create app** का बटन धूसर रहता है.
> यानी ऐप बने बिना Store listing और App content के form खुलते ही नहीं —
> भाग 1–6 का कुछ भी verification से पहले नहीं भरा जा सकता.
>
> तीन verification हैं: पहचान के कागज़ (Google की तरफ़ से, कुछ दिन),
> Android फ़ोन की जाँच (Play Console mobile app से, आप कर सकते हैं),
> और फ़ोन नंबर (बाक़ी दोनों के बाद खुलता है).


Play Console → **Create app**

- App name: `play-listing/LISTING.md` वाला (29 अक्षर)
- Default language: **हिंदी (भारत)** — या English (India), जो listing की भाषा हो
- **App**, न कि Game
- **Free** — और ध्यान रखिए, यह बाद में कभी paid नहीं किया जा सकता
- दोनों declaration पर निशान लगाइए

### 7.2 पहले App content निपटाइए

Console बिना इनके rollout नहीं करने देगा, इसलिए track बनाने से पहले ही
**Policy → App content** के सारे form भर दीजिए — जवाब इसी फ़ाइल के भाग 1–5 में हैं।
Privacy policy URL वही है जो भाग 0 में लिखा है.

Content rating और Data safety — ये दोनों ख़ास तौर पर अटकाते हैं, क्योंकि
इनके बिना कोई भी release, closed testing वाली भी, आगे नहीं बढ़ती।

### 7.3 Track बनाइए

**Test and release → Testing → Closed testing**

वहाँ पहले से एक `Alpha` track मिलेगा — उसी को इस्तेमाल कर लीजिए, या
**Create track** से अपना बना लीजिए।

### 7.4 Testers की सूची

उसी पन्ने के **Testers** tab में:

- **Google Group** चुनना ज़्यादा आसान है — बाद में लोग जोड़ने-घटाने के लिए
  Console में कुछ नहीं बदलना पड़ता, बस group में जोड़ दीजिए
- या **Create email list** — सीधे ईमेल चिपका दीजिए

हर tester का **Google खाता** चाहिए, और वही खाता उसके फ़ोन के Play Store में
लॉगिन होना चाहिए — दूसरा खाता डाला तो उसे ऐप दिखेगा ही नहीं। यही सबसे आम
शिकायत आती है।

**12 चाहिए, पर 18–20 जोड़िए** — हर कोई opt-in नहीं करता।

देश भी चुनिए (**Countries/regions**) — कम से कम भारत, वरना किसी को नहीं दिखेगा।

### 7.5 Release बनाइए और AAB चढ़ाइए

उसी track में **Create new release**

1. **App bundles** में `dist/Brahmastra-play-2.0.1.aab` को खींचकर छोड़ दीजिए
2. यहीं **Play App Signing** का पन्ना आएगा — **Continue** दबाइए। इसके बाद
   Google असली signing key अपने पास रखता है और आपकी `.jks` सिर्फ़ upload key
   रह जाती है। यही सामान्य और सुझाया हुआ तरीक़ा है
3. **Release name** अपने आप `3 (2.0.1)` भर जाएगा — रहने दीजिए
4. **Release notes** — `<hi-IN>` वाले खाने में, जैसे:
   `पहली रिलीज़ — पूरा यूपी पीईटी मुफ़्त, विषय के हिसाब से अभ्यास और मानचित्र।`

अगर चेतावनी दिखे कि deobfuscation/debug symbols नहीं हैं — वह इस AAB पर नहीं
आनी चाहिए, native debug symbols इसमें पहले से हैं।

### 7.6 Rollout

**Next → Save → Review release → Start rollout to Closed testing**

समीक्षा में आमतौर पर कुछ घंटे से कुछ दिन लगते हैं। हरा होने पर Testers tab में
**opt-in link** मिलेगा — वही सबको भेजना है (WhatsApp पर भेज दीजिए, सबसे सीधा)।

tester उस link को खोलकर **Become a tester** दबाएगा, फिर "Download it on
Google Play" से ऐप install करेगा। **सीधे Play Store में खोजने पर नहीं मिलेगा** —
यह भी साथ में बता दीजिएगा, वरना लोग ढूँढ़-ढूँढ़कर परेशान होंगे।

### 7.7 फिर 14 दिन का इंतज़ार

नए personal खाते के लिए Play माँगता है: **कम से कम 12 tester लगातार 14 दिन तक
opt-in किए हुए** रहें — गिनती opt-in की है, install की नहीं, और बीच में कोई
हटा तो घड़ी दोबारा शुरू हो सकती है।

> ठीक-ठीक शर्त और बचे हुए दिन आपके Console में **Production → Apply for
> production access** पर दिखते रहते हैं। Google यह नियम समय-समय पर बदलता रहा
> है, इसलिए अंतिम सच वही पन्ना है, यह फ़ाइल नहीं।

2–3 दिन बाद एक बार गिन लीजिए कि सचमुच कितनों ने opt-in किया; कम हों तो और
जोड़िए। पूरा होने पर **Apply for production access** माँगिए।

### 7.8 अगली build चढ़ानी हो तो

`pubspec.yaml` में versionCode ज़रूर बढ़ाइए (अभी `2.0.5+7` → अगली बार `+8`)।
वही versionCode दोबारा चढ़ाने पर Play साफ़ मना कर देता है।

---

## 8. जो हर बार upload से पहले

```bash
flutter build appbundle --release --dart-define=STORE=play
```

`--dart-define=STORE=play` भूले तो UPI वाला पन्ना AAB में चला जाएगा और
Play नीति टूटेगी। हर बार `pubspec.yaml` में versionCode भी बढ़ाना है
(अभी `2.0.5+7`)।
