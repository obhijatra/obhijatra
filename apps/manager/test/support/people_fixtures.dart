import 'package:obhijatra_manager/src/data/people.dart';

import 'fake_api.dart';

/// An invented organisation's places: a head office with two regions and
/// one branch.
const Place headOffice = Place(
  id: 'headoffice00001',
  name: 'Head office',
  code: 'HO',
  parentId: '',
  path: '/headoffice00001/',
);
const Place northRegion = Place(
  id: 'northregion0001',
  name: 'North region',
  code: 'N',
  parentId: 'headoffice00001',
  path: '/headoffice00001/northregion0001/',
);
const Place mirpurBranch = Place(
  id: 'mirpurbranch001',
  name: 'Mirpur branch',
  code: 'N-MIR',
  parentId: 'northregion0001',
  path: '/headoffice00001/northregion0001/mirpurbranch001/',
);
const Place southRegion = Place(
  id: 'southregion0001',
  name: 'South region',
  code: 'S',
  parentId: 'headoffice00001',
  path: '/headoffice00001/southregion0001/',
);

const List<Place> samplePlaces = <Place>[
  mirpurBranch,
  southRegion,
  headOffice,
  northRegion,
];

Person person({
  required String id,
  required String name,
  PersonKind kind = PersonKind.staff,
  String role = 'supervisor',
  String email = '',
  bool verified = false,
  String phone = '',
  Place place = mirpurBranch,
  bool active = true,
  bool mustChange = false,
}) => Person(
  id: id,
  kind: kind,
  name: name,
  email: email,
  verified: verified,
  phone: phone,
  role: role,
  locationId: place.id,
  locationPath: place.path,
  active: active,
  mustChangePassword: mustChange,
  created: DateTime(2026, 11, 1),
);

/// The signed-in admin (the harness's `staff('org_admin')` has id u1).
final Person tania = person(
  id: 'u1',
  name: 'Tania Rahman',
  role: 'org_admin',
  email: 'tania@example.org',
  verified: true,
  place: headOffice,
);

final Person karim = person(
  id: 's2',
  name: 'Karim Hossain',
  email: 'karim@example.org',
  phone: '+8801711111111',
);

final Person rina = person(
  id: 's3',
  name: 'Rina Akter',
  role: 'branch_manager',
  email: 'rina@example.org',
  verified: true,
  place: southRegion,
  active: false,
);

final Person nasrin = person(
  id: 'f1',
  name: 'Nasrin Sultana',
  kind: PersonKind.field,
  role: fieldOfficerRole,
  email: 'nasrin@example.org',
  phone: '+8801712345678',
  mustChange: true,
);

/// Karim's sign-in is locked from one address.
final SignInLock karimLock = SignInLock(
  id: 'lock1',
  kind: PersonKind.staff,
  accountId: 's2',
  ip: '203.0.113.7',
  failedAttempts: 10,
  lockedUntil: DateTime.now().add(const Duration(minutes: 12)),
);

/// A fake server with the sample organisation's people and places.
FakeManagerApi peopleApi(FakeManagerApi api) => api
  ..places = List<Place>.of(samplePlaces)
  ..people[PersonKind.staff]!.addAll(<Person>[karim, rina, tania])
  ..people[PersonKind.field]!.add(nasrin)
  ..locks = <SignInLock>[karimLock];
