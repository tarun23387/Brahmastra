# Developer profile — Play Console

`Developer account → Developer profile` वाला पन्ना। यह ऐप की listing से अलग है —
यह आपका अपना पन्ना है, जहाँ से लोग आपके सारे ऐप देखते हैं।

तीन field अनिवार्य हैं (`*`)। बाक़ी छोड़े जा सकते हैं।

| Field | क्या डालना है |
|---|---|
| Developer icon * | `developer-icon-512.png` |
| Header image * | `developer-header-4096x2304.png` |
| Promotional text * | नीचे लिखा text (130/140) |
| Featured app | ऐप बनने के बाद ब्रह्मास्त्र चुन लीजिए |
| Developer website | `https://exampreparation-bc34c.web.app` |

## Promotional text — 130/140 अक्षर

Default भाषा **en-US** है, इसलिए अंग्रेज़ी वाला मुख्य है:

```
Hindi question practice for UP state exams — UP PET, RO/ARO and UPPCS. One question at a time, works offline. Full UP PET is free.
```

**Manage translations → हिंदी** जोड़ना हो तो (132/140):

```
यूपी की प्रतियोगी परीक्षाओं — पीईटी, आरओ/एआरओ, यूपीपीसीएस — का प्रश्न अभ्यास। एक बार में एक प्रश्न, बिना इंटरनेट। पूरा पीईटी मुफ़्त।
```

> क़ीमत, UPI या ऐप के बाहर भुगतान का ज़िक्र यहाँ भी नहीं है — वही नियम जो
> store listing पर लागू है।

## तस्वीरें कैसे बनीं

`tools/gen-devpage.ps1` (scratchpad में) — रंग वही जो ऐप के icon में हैं:
ink `#17110B`→`#3A2B1C`, सुनहरा `#F2CF6E`→`#B0821A`.

- **developer-icon-512.png** — 512×512, 24-bit, **transparency हटाई हुई**।
  `icon-512.png` में alpha था, और Play का नियम "24-bit PNG (not transparent)"
  है, इसलिए उसे गहरे ink पर बैठाया गया।
- **developer-header-4096x2304.png** — 4096×2304, Play की तय नाप।
  सामग्री बीच में रखी है क्योंकि अलग-अलग परदों पर किनारे कट जाते हैं।
