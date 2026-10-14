# ============================================================
# R8 / ProGuard rules for Lucky Wings (release builds)
#
# Flutter's own rules and each plugin's "consumer" rules (Firebase, Google
# Play services, AdMob, Google Sign-In ...) are applied automatically; this
# file only adds what this app needs on top of them.
# ============================================================

# ─── Debuggability ────────────────────────────────────────────
# Keep line numbers so release stack traces (Crashlytics / Play Console
# vitals) can be de-obfuscated with the mapping.txt of the same build.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Reflection-based libraries (Gson, Firebase) read these at runtime.
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses

# ─── App code ─────────────────────────────────────────────────
# MainActivity hosts the audio / in-app-review MethodChannel. It is named in
# the manifest so R8 keeps it already; stated explicitly for clarity.
-keep class com.robinson.luckywings.MainActivity { *; }

# ─── flutter_local_notifications ──────────────────────────────
# Persists scheduled notifications as JSON with Gson, which needs the
# generic type information and the model classes intact. Without this,
# reminders silently fail to (re)schedule in release builds only.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# ─── Google Play in-app review (used by "Rate Us") ────────────
-keep class com.google.android.play.core.review.** { *; }
-dontwarn com.google.android.play.core.**

# ─── Google Mobile Ads / UMP consent ──────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**

# ─── Flutter engine / embedding / plugin registration ─────────
# Flutter adds its own rules; these make the plugin entry points explicit so
# a plugin can never be stripped from GeneratedPluginRegistrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase (Auth, Firestore, Functions, Messaging, Core) ───
# Each Firebase library ships consumer rules; these keep the reflection
# paths used for (de)serialising Firestore/Functions data and FCM payloads.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Google Sign-In ───────────────────────────────────────────
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.signin.** { *; }

# ─── Plugins used by the app ──────────────────────────────────
# share_plus, url_launcher, shared_preferences, firebase_*, google_*.
-keep class dev.fluttercommunity.plus.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }

# ─── Images / Bitmap ──────────────────────────────────────────
# android.graphics.* belongs to the OS and is never renamed or removed by
# R8. The app's image work (the Dart `image` package, flutter_svg,
# confetti, sprite loading) runs inside Flutter/Dart, not in Java. What
# can break are native entry points and decoder classes, so keep those:
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.BitmapFactory { *; }
-keep class androidx.core.graphics.** { *; }
-keep class androidx.exifinterface.** { *; }
-dontwarn android.graphics.**

# ─── AndroidX / Kotlin / coroutines ───────────────────────────
-keep class androidx.lifecycle.** { *; }
-keep class androidx.startup.** { *; }
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-keep class kotlinx.coroutines.android.AndroidDispatcherFactory { *; }
-keep class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**
-dontwarn kotlin.**

# ─── Generic safety net ───────────────────────────────────────
# Enum valueOf/values, Parcelable CREATOR and Serializable are all looked
# up by name at runtime.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
# WebView JavaScript bridges (AdMob renders ads in a WebView).
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ─── Misc warnings from optional dependencies ─────────────────
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn kotlin.Unit
