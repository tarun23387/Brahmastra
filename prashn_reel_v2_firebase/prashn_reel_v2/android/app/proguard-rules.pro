# firebase-appcheck-debug ko release se hataya gaya hai (build.gradle.kts dekhiye).
# FlutterFirebaseAppCheckPlugin.activate() me uska ek reference bacha rehta hai —
# woh branch release me kabhi chalti nahi (main.dart: kDebugMode ? debug :
# playIntegrity), par R8 use trace karne ki koshish karta hai aur build rok deta
# hai. Yeh line usi ek reference ko nazarandaz karne ko kehti hai.
-dontwarn com.google.firebase.appcheck.debug.**
