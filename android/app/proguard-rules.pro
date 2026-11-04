# Flutter plugins talk to Dart through Pigeon/JNI registrars that R8 cannot see
# being used. Keep every plugin package whole; the saving from shrinking them is tiny.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class dev.flutter.** { *; }
-keep class dev.steenbakker.** { *; }
-keep class dev.hebei.** { *; }
-keep class com.baseflow.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.google_mlkit_** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.trailseek.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
# JNI (jnigen) plugins look methods up by exact descriptor: no renaming anywhere.
-dontobfuscate
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.jvm.** { *; }
-keep class kotlinx.coroutines.** { *; }
