/// Why a typed server address is refused, before any network is used.
enum AddressIssue {
  /// Nothing was typed.
  empty,

  /// The text is not a web address.
  shape,

  /// The address would send passwords and data without protection.
  insecure,
}

/// The result of reading a typed server address.
typedef AddressResult = ({Uri? address, AddressIssue? issue});

/// Reads what the person typed as a server address.
///
/// "data.example.org" becomes `https://data.example.org`. Only the scheme,
/// host and port are kept. Plain `http` is accepted only for addresses on
/// this computer or its own private network (testing), never for the open
/// internet.
///
/// This is the same rule as the field app's connect screen. It is copied
/// here on purpose: the two apps do not share code for it.
AddressResult parseServerAddress(String input) {
  final text = input.trim();
  if (text.isEmpty) return (address: null, issue: AddressIssue.empty);
  if (RegExp(r'\s').hasMatch(text)) {
    return (address: null, issue: AddressIssue.shape);
  }
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty ||
      !(uri.host.contains('.') || uri.host == 'localhost')) {
    return (address: null, issue: AddressIssue.shape);
  }
  if (uri.scheme == 'http' && !isLocalHost(uri.host)) {
    return (address: null, issue: AddressIssue.insecure);
  }
  final origin = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
  return (address: origin, issue: null);
}

/// Whether [address] is plain `http` on a local or private address, which is
/// allowed for testing only.
bool isTestingAddress(Uri address) => address.scheme == 'http';

/// Whether [host] is this computer or on a private network: `localhost`,
/// `*.local`, 127/8, 10/8, 172.16/12 or 192.168/16.
bool isLocalHost(String host) {
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null || n < 0 || n > 255)) return false;
  final a = nums[0]!;
  final b = nums[1]!;
  return a == 10 ||
      a == 127 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31);
}
