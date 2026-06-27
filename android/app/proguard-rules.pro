# ── mobile_scanner / MLKit barcode scanning ──────────────────────────────────

# Keep all MLKit barcode classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep mobile_scanner plugin classes
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Keep CameraX classes used by mobile_scanner
-keep class androidx.camera.** { *; }

# Keep Kotlin metadata (required for Kotlin reflection in release)
-keepattributes RuntimeVisibleAnnotations
-keepattributes AnnotationDefault
-keep class kotlin.Metadata { *; }

# Prevent stripping of native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}