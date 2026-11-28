package com.storeph.pos

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// BiometricPrompt-based implementation on Android.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Edge-to-edge on every Android version, as Android 15+ enforces it (Play Console warning).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}