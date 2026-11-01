/// Set by the release build (`--dart-define=CROCELL_VERSION=0.3.0`);
/// local builds say "dev".
const appVersion = String.fromEnvironment('CROCELL_VERSION', defaultValue: 'dev');
