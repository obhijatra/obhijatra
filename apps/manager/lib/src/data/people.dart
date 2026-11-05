import 'package:flutter/foundation.dart';

/// The two kinds of account. Each is its own collection on the server, and
/// a person's kind is fixed once they are added.
enum PersonKind {
  /// Office staff: they sign in to this manager app.
  staff('staff_users'),

  /// Field staff: they sign in to the field app on a phone.
  field('field_users');

  const PersonKind(this.collection);

  /// The server's collection for this kind.
  final String collection;

  /// The roles a person of this kind may hold, in the order offered.
  List<String> get roles => switch (this) {
    PersonKind.staff => staffRoles,
    PersonKind.field => const <String>[fieldOfficerRole],
  };

  /// The kind stored in [collection], or null.
  static PersonKind? fromCollection(String collection) {
    for (final kind in values) {
      if (kind.collection == collection) return kind;
    }
    return null;
  }
}

/// The server's organisation admin role.
const String orgAdminRole = 'org_admin';

/// The only role of field staff.
const String fieldOfficerRole = 'field_officer';

/// Every role an office staff member may hold, as the server names them.
const List<String> staffRoles = <String>[
  'supervisor',
  'branch_manager',
  'me',
  orgAdminRole,
  'donor_readonly',
];

/// Someone who can use Obhijatra, as an organisation admin sees them.
@immutable
class Person {
  /// Creates a person.
  const Person({
    required this.id,
    required this.kind,
    required this.name,
    required this.email,
    required this.verified,
    required this.phone,
    required this.role,
    required this.locationId,
    required this.locationPath,
    required this.active,
    required this.mustChangePassword,
    this.created,
  });

  /// Record id.
  final String id;

  /// Office or field staff.
  final PersonKind kind;

  /// Full name; may be empty on an old record.
  final String name;

  /// Sign-in email address, or empty.
  final String email;

  /// Whether an admin confirmed that [email] belongs to the person (needed
  /// for Google sign-in).
  final bool verified;

  /// Mobile number in international form, or empty.
  final String phone;

  /// The server's role name, for example `supervisor`.
  final String role;

  /// Record id of the person's place.
  final String locationId;

  /// The materialised path of the person's place (set by the server).
  final String locationPath;

  /// Whether the person may sign in.
  final bool active;

  /// Whether the person has a one-time password and must choose their own.
  final bool mustChangePassword;

  /// When the account was added.
  final DateTime? created;

  /// The name to show: the full name, else the email, else the number.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return phone;
  }

  /// A copy with some values replaced.
  Person copyWith({bool? active, bool? mustChangePassword}) => Person(
    id: id,
    kind: kind,
    name: name,
    email: email,
    verified: verified,
    phone: phone,
    role: role,
    locationId: locationId,
    locationPath: locationPath,
    active: active ?? this.active,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    created: created,
  );
}

/// What an admin types about a person, to add them or to save changes.
@immutable
class PersonDraft {
  /// Creates a draft.
  const PersonDraft({
    required this.name,
    required this.role,
    required this.locationId,
    required this.email,
    required this.verified,
    required this.phone,
  });

  /// The person as they are now, to compare a draft against.
  factory PersonDraft.of(Person person) => PersonDraft(
    name: person.name,
    role: person.role,
    locationId: person.locationId,
    email: person.email,
    verified: person.verified,
    phone: person.phone,
  );

  /// Full name.
  final String name;

  /// The server's role name.
  final String role;

  /// Record id of the place.
  final String locationId;

  /// Email address, or empty.
  final String email;

  /// Whether the email address is confirmed.
  final bool verified;

  /// Mobile number in international form, or empty.
  final String phone;

  /// Every field, as the server reads them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'role': role,
    'location': locationId,
    'email': email,
    'verified': email.isNotEmpty && verified,
    'phone': phone,
  };

  /// Only the fields that differ from [person], as the server reads them.
  Map<String, dynamic> changesFrom(Person person) {
    final now = toJson();
    final before = PersonDraft.of(person).toJson();
    return <String, dynamic>{
      for (final entry in now.entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PersonDraft &&
      other.name == name &&
      other.role == role &&
      other.locationId == locationId &&
      other.email == email &&
      other.verified == verified &&
      other.phone == phone;

  @override
  int get hashCode =>
      Object.hash(name, role, locationId, email, verified, phone);
}

/// Which people the list shows by their status.
enum PeopleStatus {
  /// People who may sign in.
  active,

  /// People who may not sign in.
  deactivated,

  /// People whose sign-in is locked after too many wrong passwords.
  locked,
}

/// The order of the list.
enum PeopleSort {
  /// The most recently added first.
  newest,

  /// By name, A to Z.
  name,
}

/// Everything the server needs to find a page of people.
@immutable
class PeopleQuery {
  /// Creates a query.
  const PeopleQuery({
    this.kind = PersonKind.staff,
    this.search = '',
    this.status,
    this.placePath,
    this.sort = PeopleSort.newest,
    this.page = 1,
  });

  /// Office or field staff.
  final PersonKind kind;

  /// Text to find in the name, email address or mobile number.
  final String search;

  /// Only people with this status; null for everyone.
  final PeopleStatus? status;

  /// Only people in this place or a place below it; null for every place.
  final String? placePath;

  /// The order.
  final PeopleSort sort;

  /// 1-based page.
  final int page;

  /// How many people the server sends per page.
  static const int perPage = 50;

  /// Whether anything narrows the list.
  bool get isFiltered =>
      search.trim().isNotEmpty || status != null || placePath != null;

  /// A copy with some parts replaced. Use [clearStatus] and [clearPlace] to
  /// unset.
  PeopleQuery copyWith({
    PersonKind? kind,
    String? search,
    PeopleStatus? status,
    bool clearStatus = false,
    String? placePath,
    bool clearPlace = false,
    PeopleSort? sort,
    int? page,
  }) => PeopleQuery(
    kind: kind ?? this.kind,
    search: search ?? this.search,
    status: clearStatus ? null : (status ?? this.status),
    placePath: clearPlace ? null : (placePath ?? this.placePath),
    sort: sort ?? this.sort,
    page: page ?? this.page,
  );

  @override
  bool operator ==(Object other) =>
      other is PeopleQuery &&
      other.kind == kind &&
      other.search == search &&
      other.status == status &&
      other.placePath == placePath &&
      other.sort == sort &&
      other.page == page;

  @override
  int get hashCode => Object.hash(kind, search, status, placePath, sort, page);
}

/// One page of people.
@immutable
class PeoplePage {
  /// Creates a page.
  const PeoplePage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  /// A page with nobody on it.
  const PeoplePage.empty({this.page = 1})
    : items = const <Person>[],
      perPage = PeopleQuery.perPage,
      totalItems = 0,
      totalPages = 0;

  /// The people on this page.
  final List<Person> items;

  /// 1-based page number.
  final int page;

  /// People per page.
  final int perPage;

  /// People matching the filters, over all pages.
  final int totalItems;

  /// Number of pages.
  final int totalPages;
}

/// A sign-in lock: too many wrong passwords for one account, from one
/// address or from everywhere.
@immutable
class SignInLock {
  /// Creates a lock.
  const SignInLock({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.ip,
    required this.failedAttempts,
    required this.lockedUntil,
  });

  /// Record id.
  final String id;

  /// The kind of the locked account.
  final PersonKind kind;

  /// Record id of the locked account.
  final String accountId;

  /// The address the lock applies to; empty means every address.
  final String ip;

  /// Wrong passwords counted when it locked.
  final int failedAttempts;

  /// When the lock ends by itself.
  final DateTime lockedUntil;
}

/// A place in the organisation: a branch, an area, a region.
@immutable
class Place {
  /// Creates a place.
  const Place({
    required this.id,
    required this.name,
    required this.code,
    required this.parentId,
    required this.path,
  });

  /// Record id.
  final String id;

  /// Its name.
  final String name;

  /// A short code, or empty.
  final String code;

  /// Record id of the place above it, or empty for a top-level place.
  final String parentId;

  /// Materialised path, for example `/abc.../def.../`.
  final String path;

  /// The name, or the code when there is no name.
  String get displayName => name.trim().isNotEmpty ? name.trim() : code;
}

/// Every place, as a tree: the order to list them in, how deep each one is
/// and the names of the places above it.
class PlaceDirectory {
  /// Builds the tree from [places], in any order.
  PlaceDirectory(Iterable<Place> places) {
    for (final place in places) {
      _byId[place.id] = place;
      _byPath[place.path] = place;
    }
    final children = <String, List<Place>>{};
    for (final place in _byId.values) {
      final parent = _byId.containsKey(place.parentId) ? place.parentId : '';
      children.putIfAbsent(parent, () => <Place>[]).add(place);
    }
    int byName(Place a, Place b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    void visit(String parentId, int depth) {
      final list = children[parentId];
      if (list == null) return;
      list.sort(byName);
      for (final place in list) {
        _ordered.add(place);
        _depth[place.id] = depth;
        visit(place.id, depth + 1);
      }
    }

    visit('', 0);
  }

  final Map<String, Place> _byId = <String, Place>{};
  final Map<String, Place> _byPath = <String, Place>{};
  final List<Place> _ordered = <Place>[];
  final Map<String, int> _depth = <String, int>{};

  /// Every place, each followed by the places below it, by name.
  List<Place> get ordered => List<Place>.unmodifiable(_ordered);

  /// Whether there are no places.
  bool get isEmpty => _ordered.isEmpty;

  /// The place with record id [id].
  Place? byId(String id) => _byId[id];

  /// The place with materialised path [path].
  Place? byPath(String path) => _byPath[path];

  /// 0 for a top-level place, 1 for one below it, and so on.
  int depthOf(Place place) => _depth[place.id] ?? 0;

  /// The names from the top of the tree down to [place], for example
  /// `["North region", "Mirpur branch"]`.
  List<String> trail(Place place) {
    final names = <String>[];
    final ids = place.path.split('/').where((part) => part.isNotEmpty);
    for (final id in ids) {
      final step = _byId[id];
      if (step != null) names.add(step.displayName);
    }
    return names.isEmpty ? <String>[place.displayName] : names;
  }

  /// The name of the place at [path], or an empty string.
  String nameAt(String path) => _byPath[path]?.displayName ?? '';
}
