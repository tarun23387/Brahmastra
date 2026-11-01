/**
 * UPPCS सी-सैट: सामान्य अंग्रेज़ी (हाईस्कूल स्तर) का "पढ़िए" पाठ (1 नव॰ 2026).
 *
 * समझाना हिंदी में, उदाहरण अंग्रेज़ी में (बैंक के अंग्रेज़ी प्रश्नों की व्याख्या
 * जैसा). बैंक में UPPCS अंग्रेज़ी के असली प्रश्न नहीं हैं, इसलिए "परीक्षा में यह
 * ऐसे आया" सारणी नहीं रखी.
 */
module.exports = {
  key: 'lesson:uppcs-csat:english',
  order: 1,
  paper: 'uppcs-csat',
  subject: 'english',
  title: 'General English',
  subtitle: 'कर्ता-क्रिया का मेल, काल, article-preposition, voice-narration और शब्द-भंडार',
  free: false,
  chapters: [
    {
      id: 'uppcs-english-01',
      era: 'शुरुआत',
      title: 'General English को कैसे पढ़ें',
      minutes: 3,
      summary: 'सी-सैट में हाईस्कूल स्तर की अंग्रेज़ी; किन हिस्सों से प्रश्न आते हैं और उन्हें कैसे पढ़ें।',
      body: `सी-सैट की सामान्य अंग्रेज़ी हाईस्कूल (कक्षा 10) स्तर की है। पाठ्यक्रम में गद्यांश, active-passive voice, parts of speech, वाक्यों का रूपांतरण, direct-indirect speech, विराम चिह्न और वर्तनी, शब्दों के अर्थ, शब्द-भंडार और प्रयोग, मुहावरे और रिक्त स्थान भरना आते हैं। कोचिंग संस्थानों के अनुमान से हिंदी की तरह अंग्रेज़ी के भी हर पेपर में लगभग पंद्रह से बीस प्रश्न होते हैं, गद्यांश सहित।

अंग्रेज़ी के ज़्यादातर प्रश्न कुछ गिने-चुने नियमों पर टिके हैं: कर्ता के अनुसार क्रिया, किस काल में कौन-सा रूप, article ध्वनि से कैसे तय होता है, और कुछ शब्दों के साथ कौन-सा preposition जाता है। इन नियमों को उदाहरण के साथ पढ़िए; नियम याद हो तो error वाले प्रश्न में ग़लत भाग पढ़ते ही खटक जाता है।

शब्द-भंडार (synonym, antonym, one-word substitution, idiom) रोज़ थोड़ा-थोड़ा बढ़ता है। हर नए शब्द को उसके उलटे शब्द और एक छोटे वाक्य के साथ लिखिए; अकेला अर्थ जल्दी भूलता है।`,
      tables: [
        {
          title: 'सी-सैट अंग्रेज़ी के हिस्से',
          columns: ['हिस्सा', 'इस पाठ में'],
          rows: [
            ['Error spotting, subject-verb agreement', 'अध्याय 2'],
            ['Tenses, conditionals, question tags', 'अध्याय 3'],
            ['Articles और prepositions', 'अध्याय 4'],
            ['Voice, narration, transformation', 'अध्याय 5'],
            ['Synonym, antonym, one word, idioms, spelling', 'अध्याय 6'],
            ['Comprehension', 'गद्यांश का पाठ'],
          ],
        },
      ],
    },
    {
      id: 'uppcs-english-02',
      era: 'व्याकरण',
      title: 'कर्ता और क्रिया का मेल (Subject-Verb Agreement)',
      minutes: 8,
      summary: 'असली कर्ता पहचानना, each/neither जैसे शब्द, और senior to जैसे प्रयोग।',
      body: `अंग्रेज़ी में क्रिया का रूप कर्ता (subject) के वचन से तय होता है: एकवचन कर्ता के साथ is/was/has और Present Simple में -s, बहुवचन के साथ are/were/have। ग़लती तब होती है जब कर्ता और क्रिया के बीच कोई दूसरा वाक्यांश आ जाए। "The quality of these mangoes are not good." में क्रिया "mangoes" से मेल खा रही है, जबकि असली कर्ता "The quality" एकवचन है, इसलिए सही "is" है। बीच में आए of…, with…, along with…, as well as… वाले वाक्यांश कर्ता नहीं बदलते: The teacher, along with his students, is coming.

Each, every, either, neither, everyone, somebody जैसे शब्द एकवचन माने जाते हैं, भले उनके बाद "of the boys" जैसा बहुवचन वाक्यांश आए: "Neither of the two boys has finished the work." "One of my friends is a doctor" में भी कर्ता "One" है। इसके उलट दो कर्ता and से जुड़े हों तो क्रिया बहुवचन होती है (Ram and Shyam are friends), और either…or या neither…nor से जुड़े हों तो क्रिया पास वाले कर्ता के अनुसार चलती है (Neither the teacher nor the students were present)।

कुछ शब्द तुलना के लिए than नहीं, to लेते हैं, क्योंकि वे लैटिन से आए हैं और उनमें तुलना पहले से है: senior, junior, superior, inferior, prior। "He is senior to me", "This cloth is superior to that"। Prefer भी to लेता है: I prefer tea to coffee।`,
      tables: [
        {
          title: 'मेल के नियम',
          columns: ['स्थिति', 'उदाहरण'],
          rows: [
            ['बीच का of/with वाला वाक्यांश कर्ता नहीं बदलता', 'The quality of these mangoes is not good.'],
            ['Each, every, either, neither → एकवचन', 'Each of the students was given a prize.'],
            ['A and B → बहुवचन', 'Ram and Shyam are friends.'],
            ['Neither A nor B → पास वाले कर्ता से', 'Neither the teacher nor the students were present.'],
            ['senior/junior/superior/inferior/prior + to', 'He is senior to me.'],
          ],
        },
      ],
    },
    {
      id: 'uppcs-english-03',
      era: 'व्याकरण',
      title: 'काल, शर्त वाले वाक्य और question tag',
      minutes: 9,
      summary: 'since-for, Past Perfect कब, तीनों conditionals, और question tag बनाने का नियम।',
      body: `जो काम अतीत में शुरू होकर अब तक चल रहा हो, उसके लिए Present Perfect Continuous (have/has been + V-ing) आता है: "I have been living in Lucknow since 2015." हिंदी में हम "रह रहा हूँ" कहते हैं, इसलिए "I am living … since 2015" लिखने की भूल होती है। since किसी बिंदु-समय (2015, Monday, morning) के साथ और for अवधि (ten years, two hours) के साथ आता है।

अतीत की दो घटनाओं में जो पहले पूरी हुई, वह Past Perfect (had + V3) में जाती है और बाद वाली Past Simple में: "By the time we reached the station, the train had left." ट्रेन हमारे पहुँचने से पहले जा चुकी थी।

शर्त वाले वाक्य तीन तरह के हैं। भविष्य की असली संभावना (First Conditional): If + Present Simple, will + V1 — "If it rains, we will stay at home." काल्पनिक या असंभव स्थिति (Second): If + Past Simple, would + V1 — "If I were rich, I would buy a house." यहाँ हर कर्ता के साथ were आता है। अतीत की ऐसी शर्त जो पूरी नहीं हुई (Third): If + had + V3, would have + V3 — "If he had worked hard, he would have passed."

Question tag में सकारात्मक वाक्य के बाद नकारात्मक tag आता है, और नकारात्मक के बाद सकारात्मक; tag में वही सहायक क्रिया और काल रहता है: "He is a doctor, isn't he?", "She can swim, can't she?" वाक्य में सहायक क्रिया न हो, तो do/does/did लगता है: "He works here, doesn't he?"`,
      tables: [
        {
          title: 'काल और शर्त के रूप',
          columns: ['स्थिति', 'ढाँचा', 'उदाहरण'],
          rows: [
            ['अतीत से अब तक चल रहा काम', 'have/has been + V-ing + since/for', 'She has been working here for ten years.'],
            ['अतीत में पहले पूरी हुई घटना', 'had + V3', 'The train had left before we reached.'],
            ['First Conditional', 'If + V1/s, will + V1', 'If it rains, we will stay at home.'],
            ['Second Conditional', 'If + V2 (were), would + V1', 'If I were rich, I would buy a house.'],
            ['Third Conditional', 'If + had + V3, would have + V3', 'If he had worked hard, he would have passed.'],
            ['Question tag', 'सकारात्मक → नकारात्मक tag', "He is a doctor, isn't he?"],
          ],
        },
      ],
    },
    {
      id: 'uppcs-english-04',
      era: 'व्याकरण',
      title: 'Articles और Prepositions',
      minutes: 8,
      summary: 'a और an अक्षर से नहीं, ध्वनि से; और वे शब्द जिनके साथ एक तय preposition जाता है।',
      body: `a और an का चुनाव अक्षर से नहीं, उच्चारण की पहली ध्वनि से होता है। honest, hour और heir में h बोला नहीं जाता, शब्द स्वर-ध्वनि से शुरू होता है, इसलिए an honest man, an hour। इसके उलट European, university और one-rupee स्वर अक्षर से लिखे जाते हैं, पर उच्चारण "यू" या "वन" (व्यंजन-ध्वनि) से शुरू होता है, इसलिए a European, a university, a one-rupee coin। संक्षिप्त रूपों में भी यही नियम है: an MLA (एम-एल-ए की पहली ध्वनि "ए" है), an MBA।

The किसी निश्चित या पहले बताई गई वस्तु के लिए आता है, और कुछ जगह नियम से: अद्वितीय वस्तुएँ (the sun, the earth), नदियाँ और महासागर (the Ganga, the Pacific), पुस्तकें और समाचारपत्र (the Ramayana, the Hindu), और superlative (the best)।

कुछ शब्द अपने साथ एक तय preposition लेते हैं, और इन्हें जोड़े के रूप में ही याद करना पड़ता है: fond of, afraid of, proud of, accused of, but charged with; good at, angry with (व्यक्ति पर) but angry at (बात पर); prevent from, insist on, depend on, consist of, prefer to। समय के लिए at (बिंदु: at 5 o'clock), on (दिन और तारीख़: on Monday) और in (महीना, वर्ष, लंबी अवधि: in June, in 2025) आते हैं।`,
      tables: [
        {
          title: 'a या an — ध्वनि देखिए',
          columns: ['an (स्वर-ध्वनि)', 'a (व्यंजन-ध्वनि)'],
          rows: [
            ['an honest man, an hour, an heir', 'a European, a university, a union'],
            ['an MLA, an MBA, an X-ray', 'a one-rupee coin, a one-way street'],
          ],
        },
        {
          title: 'तय prepositions',
          columns: ['शब्द', 'preposition'],
          rows: [
            ['fond, afraid, proud, aware, accused', 'of'],
            ['charged (आरोप)', 'with'],
            ['good, clever (किसी काम में)', 'at'],
            ['prevent, refrain, differ', 'from'],
            ['insist, depend, rely', 'on'],
            ['prefer, senior, superior', 'to'],
            ['समय: बिंदु / दिन-तारीख़ / महीना-वर्ष', 'at / on / in'],
          ],
        },
      ],
    },
    {
      id: 'uppcs-english-05',
      era: 'वाक्य बदलना',
      title: 'Voice, Narration और वाक्यों का रूपांतरण',
      minutes: 10,
      summary: 'Passive बनाने के नियम (प्रश्न और आज्ञा सहित), indirect speech में काल और सर्वनाम, और no sooner…than।',
      body: `Active से Passive में कर्म कर्ता की जगह आता है, क्रिया be + V3 बनती है, और कर्ता by के साथ अंत में जाता है: "She writes a letter" → "A letter is written by her." काल वही रहता है जो मूल वाक्य का था, केवल be का रूप बदलता है (is written, was written, has been written)। प्रश्नवाचक वाक्य में प्रश्न का ढाँचा बना रहता है: "Who wrote this letter?" → "By whom was this letter written?" आज्ञावाचक वाक्य let से बनता है: "Open the door" → "Let the door be opened."

Indirect speech में कहने वाले के शब्द उसकी ओर से बताए जाते हैं, इसलिए सर्वनाम बदलते हैं (I → he/she) और मुख्य क्रिया Past में हो तो काल एक क़दम पीछे जाता है: am/is → was, do → did, will → would। "He said, 'I am tired'" → "He said that he was tired." Said to प्रश्न में asked बनता है और प्रश्न का क्रम सामान्य कथन जैसा हो जाता है: "She said to me, 'Where do you live?'" → "She asked me where I lived" (where did I live नहीं)। told के बाद सुनने वाला (object) चाहिए: He told me that…, केवल "He told that" नहीं।

वाक्यों के रूपांतरण में कुछ जोड़े तय हैं। "As soon as he saw the police, he ran away" → "No sooner did he see the police than he ran away." No sooner के साथ than आता है, और Hardly/Scarcely के साथ when (Hardly had he seen the police when he ran away)। No sooner, hardly, never जैसे नकारात्मक शब्द से वाक्य शुरू हो तो सहायक क्रिया कर्ता से पहले आती है (did he see)।`,
      tables: [
        {
          title: 'Active से Passive',
          columns: ['Active', 'Passive'],
          rows: [
            ['She writes a letter.', 'A letter is written by her.'],
            ['She wrote a letter.', 'A letter was written by her.'],
            ['She has written a letter.', 'A letter has been written by her.'],
            ['Who wrote this letter?', 'By whom was this letter written?'],
            ['Open the door.', 'Let the door be opened.'],
          ],
        },
        {
          title: 'Indirect speech में बदलाव (मुख्य क्रिया Past में)',
          columns: ['Direct', 'Indirect'],
          rows: [
            ['am / is / are', 'was / were'],
            ['do / does', 'did'],
            ['will / can', 'would / could'],
            ['said to (प्रश्न)', 'asked (कथन जैसा क्रम)'],
            ['this / here / now', 'that / there / then'],
          ],
        },
      ],
    },
    {
      id: 'uppcs-english-06',
      era: 'शब्द-भंडार',
      title: 'शब्द-भंडार — पर्याय, विलोम, एक शब्द, मुहावरे और वर्तनी',
      minutes: 9,
      summary: 'शब्द को उसके मूल से याद करना, मिलते-जुलते शब्दों का भेद, और अक्सर ग़लत लिखी जाने वाली वर्तनियाँ।',
      body: `अंग्रेज़ी के बहुत से शब्द लैटिन और यूनानी मूलों से बने हैं, और मूल पहचान लें तो अनजाना शब्द भी खुल जाता है। omni का अर्थ "सब" है: omniscient (सब जानने वाला), omnipotent (सर्वशक्तिमान), omnipresent (सर्वव्यापी), omnivorous (सब कुछ खाने वाला)। somnus "नींद" है: somnambulist (नींद में चलने वाला), insomnia (नींद न आना)। in- और un- अक्सर "नहीं" का अर्थ देते हैं: incorrigible (जिसे सुधारा न जा सके), invincible (जिसे जीता न जा सके), indelible (जो मिटे नहीं)।

पर्याय और विलोम के प्रश्नों में ग़लत विकल्प प्रायः उसी शब्द के उलटे अर्थ का होता है, या ध्वनि में मिलता-जुलता। Lucid का अर्थ clear है, lucky से उसका कोई संबंध नहीं; humble का विलोम arrogant है, जबकि modest और meek उसके पर्याय हैं। इसलिए पहले तय कीजिए कि प्रश्न पर्याय माँग रहा है या विलोम।

मुहावरे का अर्थ उसके शब्दों से नहीं, प्रयोग से आता है: a bolt from the blue (अचानक आई अनपेक्षित घटना), to beat about the bush (मुख्य बात पर न आना), to burn the midnight oil (देर रात तक काम करना), a white elephant (महँगी पर बेकार चीज़)। विकल्पों में अक्सर शब्दशः अर्थ रखा जाता है (blue = नीला आसमान), उसे छोड़ दीजिए।

कुछ वर्तनियाँ बार-बार ग़लत लिखी जाती हैं, क्योंकि उनमें अक्षर दोहरे होते हैं: accommodation (cc, mm), embarrassment (rr, ss), occurrence (cc, rr), committee (mm, tt, ee), necessary (एक c, दो s)।`,
      tables: [
        {
          title: 'मूल से बने शब्द',
          columns: ['मूल (अर्थ)', 'शब्द'],
          rows: [
            ['omni (सब)', 'omniscient, omnipotent, omnipresent, omnivorous'],
            ['somnus (नींद)', 'somnambulist, insomnia, insomniac'],
            ['in- (नहीं)', 'incorrigible, invincible, indelible, inevitable'],
            ['bene- (अच्छा) / mal- (बुरा)', 'benevolent / malevolent'],
            ['ex tempore (उसी समय)', 'extempore — बिना तैयारी का भाषण'],
          ],
        },
        {
          title: 'अक्सर ग़लत लिखी जाने वाली वर्तनियाँ',
          columns: ['सही', 'आम भूल'],
          rows: [
            ['accommodation', 'accomodation'],
            ['embarrassment', 'embarassment'],
            ['occurrence', 'occurence'],
            ['committee', 'commitee'],
            ['necessary', 'neccessary'],
          ],
        },
      ],
    },
  ],
};
