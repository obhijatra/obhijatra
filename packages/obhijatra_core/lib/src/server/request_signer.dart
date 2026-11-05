// Device trust (the check code, device keys and signed requests) lives in
// package:obhijatra_device, shared with the manager app
// (docs/decisions/0008-device-trust.md). The core passes it on; the field
// app has its own toBanglaDigits for all text.
export 'package:obhijatra_device/obhijatra_device.dart' hide toBanglaDigits;
