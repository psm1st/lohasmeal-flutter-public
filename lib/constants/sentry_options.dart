class SentryOptionsConfig {
  /// Replace with your own Sentry DSN before shipping.
  static const String SENTRY_DSN = "https://YOUR_PUBLIC_KEY@o0.ingest.sentry.io/0";
  static const String ATTACH_STACKTRACE = "true";
  static const double TRACE_SAMPLE_RATE = 0.2;
  static const double PROFILE_SAMPLE_RATE = 0.2;
}
