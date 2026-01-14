# Flutter-specific ProGuard rules

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Play Services
-keep class com.google.android.play.core.** { *; }

# Keep Gson serialization  
-keepattributes Signature
-keepattributes *Annotation*

# Keep R8 compatible with reflection
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep SharedPreferences callback
-keepclassmembers class * {
  public <init>(android.content.Context);
}

# Prevent stripping important interfaces
-keep interface * { *; }
