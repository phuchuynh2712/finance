package com.finance.finance

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth_android's
// BiometricPrompt integration, which needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
