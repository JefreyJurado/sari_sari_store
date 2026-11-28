# R8 keep rules for the release build. Flutter, mobile_scanner and androidx ship their own rules;
# only what the plugins leave out is here.

# flutter_local_notifications 17.x stores scheduled notifications (zonedSchedule) as Gson JSON and
# reads them back by reflection; it ships no R8 rules (see its README "Release build configuration").
# Keeping the model fields also keeps already-scheduled reminders readable after an app update.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson (rules from the Gson project's android-proguard-example), needed by the plugin above.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
