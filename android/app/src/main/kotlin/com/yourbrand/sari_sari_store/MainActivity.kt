package com.storeph.pos

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// BiometricPrompt-based implementation on Android.
class MainActivity : FlutterFragmentActivity()