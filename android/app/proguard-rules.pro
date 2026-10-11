# ML Kit text recognition references the optional Chinese, Devanagari,
# Japanese and Korean script modules. The app reads Latin price boards only
# and doesn't bundle them, so R8 must not fail on their absence.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
