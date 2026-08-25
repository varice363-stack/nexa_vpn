# Nexa VPN — ProGuard/R8 rules for the release build.

# Flutter engine and embedding.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage relies on the AndroidX security library.
-keep class androidx.security.crypto.** { *; }

# Keep annotations used for reflection by plugins.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Play Core is referenced by the Flutter embedding for deferred components,
# which this app does not use. Without these rules R8 fails on missing classes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep native method names so JNI bindings keep working.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve line numbers for readable crash reports, but hide the original
# source file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
