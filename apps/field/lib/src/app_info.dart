/// The release of this app, reported to the server and shown on the About
/// screen. Keep in step with `version:` in `pubspec.yaml`; a test checks it.
const String appReleaseVersion = '0.1.0';

/// The build number after the `+` in `pubspec.yaml`.
const String appBuildNumber = '1';

/// Where the source code of the app is published (AGPL-3.0 asks us to offer
/// it). Taken from the Go module path of the repository
/// (`github.com/obhijatra/obhijatra`); the owner should confirm it is the
/// public address.
const String sourceCodeUrl = 'https://github.com/obhijatra/obhijatra';

/// The settings key that remembers the organisation's server address.
const String serverUrlSettingKey = 'server.base_url';

/// The settings key that remembers the language the person chose.
const String languageSettingKey = 'ui.language';
