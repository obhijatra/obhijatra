// The device keys' storage for the platform the app is built for. Desktop
// builds never import the web code, and the web build never imports the
// desktop store.
export 'package:obhijatra_manager/src/device/identity_store_desktop.dart'
    if (dart.library.js_interop) 'package:obhijatra_manager/src/device/identity_store_web.dart'
    show platformIdentityStore, platformUserAgent;
