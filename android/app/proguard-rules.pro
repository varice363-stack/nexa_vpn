# ProGuard rules for Morok VPN

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Riverpod
-keep class com.example.** { *; }
-keepnames class * extends com.example.**

# Keep JSON serialization (Gson/JSON)
-keepattributes Signature
-keepattributes *Annotation*
-keep class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepnames class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep models (used in JSON serialization)
-keep class com.nexavpn.app.models.** { *; }
-keep class com.morokvpn.app.models.** { *; }

# Keep Xray/V2Ray native classes
-keep class com.github.xray.** { *; }
-keep class libv2ray.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Suppress warnings
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn kotlin.**
-dontwarn javax.annotation.**

# Optimization
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose
