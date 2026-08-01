package com.example.car_rent_manager

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth shows the system biometric prompt through AndroidX BiometricPrompt,
// which needs a FragmentActivity host. Extending FlutterActivity instead makes
// authenticate() fail at runtime with a no_fragment_activity error.
class MainActivity : FlutterFragmentActivity()
