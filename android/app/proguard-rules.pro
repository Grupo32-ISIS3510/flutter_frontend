# =============================================================================
# ProGuard / R8 rules — Second Serving
# =============================================================================
#
# Only Latin text recognition is bundled with this app, but the
# google_mlkit_text_recognition plugin references the option classes for the
# other language modules (Chinese / Devanagari / Japanese / Korean). Without
# these `-dontwarn` rules, R8 fails the release build with "Missing class …".
#
# Auto-generated reference: build/app/outputs/mapping/release/missing_rules.txt
# -----------------------------------------------------------------------------

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep the ML Kit Vision classes we DO use — the plugin reaches them by
# reflection, so renaming would break runtime.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }

# Firebase Messaging — keep the FCM service entry points (used by FlutterFire).
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# Standard Flutter safety: keep plugin registrants and method-channel entry
# points (Flutter ships consumer rules for most, but these are cheap insurance).
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.common.** { *; }

# -----------------------------------------------------------------------------
# Flutter — Play Core / Deferred Components
# -----------------------------------------------------------------------------
# Flutter's embedding references Play Feature Delivery (deferred component)
# classes even when the feature is unused. We don't ship deferred components,
# so we tell R8 to ignore those references instead of pulling in com.google.
# android.play:feature-delivery just to satisfy them.
-dontwarn com.google.android.play.core.**
