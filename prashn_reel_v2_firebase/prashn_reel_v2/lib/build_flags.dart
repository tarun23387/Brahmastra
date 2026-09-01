/// यह build किस रास्ते बाँटी जा रही है.
///
/// दो रास्ते हैं और दोनों के नियम अलग हैं:
///
///   • `direct` — अपनी बनाई APK, जो सीधे छात्रों को दी जाती है. इसमें UPI
///     वाला भुगतान का पन्ना रहता है, क्योंकि यहाँ Google बीच में नहीं है.
///
///   • `play`  — Play Store वाली build. Google की नीति कहती है कि ऐप के
///     अंदर बिकने वाली डिजिटल चीज़ का पैसा Play Billing से ही लिया जाए.
///     सीधे UPI माँगना — या उसकी तरफ़ इशारा तक करना — ऐप को reject या बाद
///     में remove करा देता है. इसलिए उस build में भुगतान का कोई ज़िक्र नहीं
///     होता: न पन्ना, न बटन, न क़ीमत, न नंबर.
///
/// बनाते वक़्त तय होता है:
///   flutter build appbundle --release --dart-define=STORE=play
///   flutter build apk       --release --dart-define=STORE=direct
///
/// कुछ न दिया जाए तो `direct` ही माना जाता है, ताकि रोज़ का काम
/// (`flutter run`) पहले जैसा चलता रहे.
const String kStore = String.fromEnvironment('STORE', defaultValue: 'direct');

/// Play Store वाली build है या नहीं.
const bool kIsPlayBuild = kStore == 'play';
