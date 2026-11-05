// Package schema holds the names, roles and row-level API rules of
// Obhijatra's data model, so that migrations, hooks, routes and tests all
// use one definition.
package schema

import (
	"regexp"
	"time"
)

// Collection names.
const (
	Settings     = "settings"
	Locations    = "locations"
	FieldUsers   = "field_users"
	StaffUsers   = "staff_users"
	Forms        = "forms"
	FormVersions = "form_versions"
	Submissions  = "submissions"
	Devices      = "devices"
	Sessions     = "sessions"
	LoginLocks   = "login_locks"
	Audit        = "audit"

	// Superusers is PocketBase's built-in superuser collection.
	Superusers = "_superusers"

	// LoginFailuresTable holds recent wrong passwords per account. It is a
	// plain table, not a collection: the server's own counter (like
	// PocketBase's rate limiter), invisible to the API and the Dashboard,
	// and not in the audit chain, so unauthenticated traffic cannot grow
	// the chain. The locks themselves are login_locks records, which are.
	LoginFailuresTable = "_obhijatra_login_failures"

	// SignInSettingsTable holds the sign-in settings an org admin chooses
	// that PocketBase has no place for (phone sign-in and the SMS
	// provider), encrypted with the server settings key. A plain table,
	// invisible to the API and the Dashboard; changes are audit events.
	SignInSettingsTable = "_obhijatra_signin"

	// SignInAttemptsTable counts sign-in code requests and checks, for
	// the per-number and per-address limits. A plain table, like
	// LoginFailuresTable, so unauthenticated traffic cannot grow the
	// audit chain.
	SignInAttemptsTable = "_obhijatra_signin_attempts"

	// PhoneCodesTable holds the SMS sign-in codes sent and not yet used
	// (hashed), with their tries. A plain table, so unauthenticated
	// requests cannot grow the audit chain.
	PhoneCodesTable = "_obhijatra_phone_codes"
)

// CoreCollections cannot be renamed or deleted, because the API rules,
// hooks and routes refer to them by name.
var CoreCollections = []string{
	Settings, Locations, FieldUsers, StaffUsers, Forms, FormVersions,
	Submissions, Devices, Sessions, LoginLocks, Audit,
}

// IsCoreCollection reports whether name is one of CoreCollections.
func IsCoreCollection(name string) bool {
	for _, c := range CoreCollections {
		if c == name {
			return true
		}
	}
	return false
}

// Size limits for uploaded files.
const (
	mib = 1 << 20

	// MaxXMLSize caps an XForm definition or a submission instance. It is
	// checked by the hooks on both file fields and by package xform, which
	// reads every XML document in full; real XForms with several languages
	// stay well under 1 MiB, and submission instances are a few KiB.
	MaxXMLSize = 10 * mib
	// MaxAttachmentSize caps one media file sent with a submission.
	MaxAttachmentSize = 100 * mib
	// MaxAttachments caps the number of media files on one submission.
	MaxAttachments = 50
)

// Roles. Field users have one role; staff users have one of the staff roles.
const (
	RoleFieldOfficer  = "field_officer"
	RoleSupervisor    = "supervisor"
	RoleBranchManager = "branch_manager"
	RoleME            = "me" // monitoring and evaluation
	RoleOrgAdmin      = "org_admin"
	RoleDonorReadonly = "donor_readonly"
)

// StaffRoles lists every role a staff user may hold.
var StaffRoles = []string{RoleSupervisor, RoleBranchManager, RoleME, RoleOrgAdmin, RoleDonorReadonly}

// Submission review states.
const (
	ReviewReceived  = "Received"
	ReviewEdited    = "Edited"
	ReviewHasIssues = "HasIssues"
	ReviewApproved  = "Approved"
	ReviewRejected  = "Rejected"
)

// ReviewStates lists every review state, in workflow order.
var ReviewStates = []string{ReviewReceived, ReviewEdited, ReviewHasIssues, ReviewApproved, ReviewRejected}

// ReviewFields are the only submission fields a reviewer may change; the
// guards hook refuses a change to any other field, for superusers too.
var ReviewFields = []string{"review_state", "review_comment"}

// MaxReviewComment caps a reviewer's comment, in characters.
const MaxReviewComment = 2000

// Sign-in protection (see docs/decisions/0002-obhijatra-server.md).
const (
	// AuthRateLimitRequests sign-in attempts per AuthRateLimitSeconds from
	// one IP address, per user collection: enough for a branch office of
	// about 30 staff behind one internet connection to sign in together.
	AuthRateLimitRequests = 30
	AuthRateLimitSeconds  = 60

	// LockoutMaxFailures wrong passwords for one account from one IP
	// address within LockoutWindow lock the account, for that address
	// only, for LockoutDuration. LockoutDuration must not be shorter than
	// LockoutWindow, so a lock that runs out also starts a fresh count.
	LockoutMaxFailures = 10
	LockoutWindow      = 15 * time.Minute
	LockoutDuration    = 15 * time.Minute

	// AccountMaxFailures wrong passwords for one account within
	// LockoutWindow, from all IP addresses together, lock an ordinary
	// account for every address for LockoutDuration. A privileged account
	// (an org admin or a superuser) is never locked this way, because
	// whoever could lock it could then keep everyone from unlocking
	// anything: each of its sign-in attempts waits instead, from
	// AccountDelayBase, doubling with every further wrong password, up to
	// AccountDelayMax.
	AccountMaxFailures = 30
	AccountDelayBase   = time.Second
	AccountDelayMax    = 30 * time.Second
)

// LockableCollections are the auth collections whose accounts can be
// locked after repeated wrong passwords.
var LockableCollections = []string{FieldUsers, StaffUsers, Superusers}

// Sign-in methods besides email and password
// (docs/decisions/0005-sign-in-methods.md).
const (
	// GoogleProvider is PocketBase's name for Google sign-in (OAuth2).
	GoogleProvider = "google"

	// PhonePattern is the only shape a stored phone number may take: the
	// international (E.164) form, a "+" and 8 to 15 digits, for example
	// "+8801712345678".
	PhonePattern = `^\+[1-9][0-9]{7,14}$`

	// PhoneCodeLength digits in an SMS sign-in code; PhoneCodeLifetime
	// before it expires; PhoneCodeMaxTries wrong entries before it is
	// thrown away and a new one is needed.
	PhoneCodeLength   = 6
	PhoneCodeLifetime = 5 * time.Minute
	PhoneCodeMaxTries = 3

	// PhoneCodeResendAfter is how long the apps wait before offering to
	// send another code.
	PhoneCodeResendAfter = 60 * time.Second

	// Limits on sending codes, which cost the organisation money: per
	// phone number, PhoneCodesPerWindow within PhoneCodeWindow and
	// PhoneCodesPerDay within 24 hours; per IP address,
	// PhoneCodesPerIP within PhoneCodeWindow (a branch office of about 30
	// staff behind one internet connection). Code checks are limited to
	// PhoneChecksPerIP within PhoneCodeWindow per address.
	PhoneCodesPerWindow = 3
	PhoneCodesPerDay    = 10
	PhoneCodesPerIP     = 30
	PhoneChecksPerIP    = 60
	PhoneCodeWindow     = 15 * time.Minute

	// PhoneRoutesRateLimitLabel is PocketBase's own per-address rate limit
	// rule for the SMS-code routes (AuthRateLimitRequests per
	// AuthRateLimitSeconds, like sign-in), before Obhijatra's own counts.
	PhoneRoutesRateLimitLabel = "/api/obhijatra/v1/signin/phone/"
)

// PhoneSignInCollections are the auth collections whose users may sign in
// with an SMS code. Org admins are refused per account (package signin):
// a swapped SIM card must not hand over the accounts that control every
// other account.
var PhoneSignInCollections = []string{FieldUsers, StaffUsers}

// Places (the locations collection).
const (
	// MaxPlacesImport rows in one spreadsheet import, and MaxPlaceDepth
	// levels in one row.
	MaxPlacesImport = 5000
	MaxPlaceDepth   = 10
)

// MustChangePassword is the user field an org admin sets with a one-time
// password. While it is set, the server answers only the requests needed
// to choose a new password (package api); the person's own password change
// clears it (package guards). Nobody can set it on themselves.
const MustChangePassword = "must_change_password"

// PhoneRegex is PhonePattern compiled.
var PhoneRegex = regexp.MustCompile(PhonePattern)

// MaxSuperusers caps the superuser accounts: the one init creates for
// installation and recovery, and one spare. A guard refuses a third, for
// every writer, and records the refusal in the audit chain.
const MaxSuperusers = 2

// Device values.
const (
	DeviceActive  = "active"
	DeviceRevoked = "revoked"

	AttestationNone     = "none"
	AttestationSoftware = "software"
	AttestationHardware = "hardware"
)

// DeviceTrustFields are the device fields that decide whether a device is
// trusted: its keys, the organisation's signature, its status and its
// expiry. Only the server sets them, through the device-enrolment route
// (zero-trust milestone); the guards refuse them in every records-API
// create or update, from superusers too.
var DeviceTrustFields = []string{"sign_public_key", "enc_public_key", "org_signature", "status", "expires"}

// DeviceEnrolPath is the only way a device will be enrolled (zero-trust
// milestone); until then it answers 501 Not Implemented.
const DeviceEnrolPath = "/api/obhijatra/v1/devices/enrol"

// LocationPathPattern is the only shape a materialised location path may
// take: the record ids (15 lower-case letters or digits) of every location
// from the root down to the node itself, each followed by "/", with a
// leading "/". Example: "/a1b2c3d4e5f6g7h/q9w8e7r6t5y4u3i/".
//
// Because every path starts at a root and record ids are unique, a path P
// occurs inside another path Q only as Q's prefix. The API rules rely on
// this: PocketBase's "~" operator is a contains test, which for these paths
// is the same as "starts with".
const LocationPathPattern = `^/([a-z0-9]{15}/)+$`

// LocationPathRegex is LocationPathPattern compiled.
var LocationPathRegex = regexp.MustCompile(LocationPathPattern)

// ---------------------------------------------------------------------
// Row-level API rules
// ---------------------------------------------------------------------
//
// Every rule starts with Active, so a deactivated account loses access on
// its next request even while its token is still valid. Superusers bypass
// API rules (PocketBase behaviour); the Go hooks in package guards and
// package audit bind them instead.

const (
	// Active: an authenticated, active user of either user collection.
	Active = `@request.auth.id != "" && @request.auth.active = true`

	isField    = `@request.auth.collectionName = "` + FieldUsers + `"`
	isStaff    = `@request.auth.collectionName = "` + StaffUsers + `"`
	isOrgAdmin = `(` + isStaff + ` && @request.auth.role = "` + RoleOrgAdmin + `")`

	// staffReader: staff roles that may read operational records in their
	// part of the organisation tree. donor_readonly is deliberately absent:
	// donors get aggregate reports, never beneficiary-level records.
	staffReader = `(` + isStaff + ` && (@request.auth.role = "` + RoleSupervisor +
		`" || @request.auth.role = "` + RoleBranchManager +
		`" || @request.auth.role = "` + RoleME + `"))`

	// staffReviewer: staff roles that may set a submission's review state
	// and comment, within their part of the organisation tree.
	staffReviewer = `(` + isStaff + ` && (@request.auth.role = "` + RoleSupervisor +
		`" || @request.auth.role = "` + RoleBranchManager +
		`" || @request.auth.role = "` + RoleME +
		`" || @request.auth.role = "` + RoleOrgAdmin + `"))`

	// formManager: staff roles that may create forms and upload and publish
	// form versions (forms are organisation-wide, not location-scoped).
	formManager = `(` + isStaff + ` && (@request.auth.role = "` + RoleME +
		`" || @request.auth.role = "` + RoleOrgAdmin + `"))`

	// inScope: the record's location_path lies under the user's own.
	// The empty-path guard stops "~ ''" (which would match everything).
	inScope = `(@request.auth.location_path != "" && location_path ~ @request.auth.location_path)`
)

// OrgAdminOnly allows only an active org admin.
const OrgAdminOnly = Active + ` && ` + isOrgAdmin

// AnyActiveUser allows any active field or staff user.
const AnyActiveUser = Active

// Settings rules.
const (
	SettingsRead   = AnyActiveUser
	SettingsUpdate = OrgAdminOnly + ` && @request.body.schema_version:isset = false`
)

// Location rules. Every active staff user may read the whole organisation
// tree (names and paths), which the manager app needs to name the places
// in its lists; it is not personal data. A field user reads only their own
// location and the locations below it. The empty-path guard stops a "~"
// test against an empty path, which would match every location.
const (
	LocationsRead = Active + ` && (` + isStaff +
		` || (` + isField + ` && @request.auth.location_path != "" && path ~ @request.auth.location_path))`
	LocationsWrite = OrgAdminOnly
	// LocationsDelete lets an org admin delete a place; the guards allow it
	// only for a place nothing uses (no places inside, no people, no
	// records), so records never point at a missing place.
	LocationsDelete = OrgAdminOnly
)

// userSelfUpdate lets users change their own name and password but none of
// the fields that decide what they can see or how they sign in.
func userSelfUpdate(collection string) string {
	return `(@request.auth.collectionName = "` + collection + `" && id = @request.auth.id` +
		` && @request.body.role:isset = false` +
		` && @request.body.location:isset = false` +
		` && @request.body.location_path:isset = false` +
		` && @request.body.active:isset = false` +
		` && @request.body.email:isset = false` +
		` && @request.body.phone:isset = false` +
		` && @request.body.verified:isset = false` +
		` && @request.body.must_change_password:isset = false)`
}

// Field user rules.
var (
	FieldUsersRead = Active + ` && (` +
		`(` + isField + ` && id = @request.auth.id)` +
		` || ` + isOrgAdmin +
		` || (` + staffReader + ` && ` + inScope + `))`
	FieldUsersCreate = OrgAdminOnly
	FieldUsersUpdate = Active + ` && (` + isOrgAdmin + ` || ` + userSelfUpdate(FieldUsers) + `)`
	FieldUsersManage = OrgAdminOnly
)

// Staff user rules.
var (
	StaffUsersRead = Active + ` && (` +
		`(` + isStaff + ` && id = @request.auth.id)` +
		` || ` + isOrgAdmin +
		` || (` + staffReader + ` && ` + inScope + `))`
	StaffUsersCreate = OrgAdminOnly
	StaffUsersUpdate = Active + ` && (` + isOrgAdmin + ` || ` + userSelfUpdate(StaffUsers) + `)`
	StaffUsersManage = OrgAdminOnly
)

// AuthRule is checked by PocketBase after a correct password and before a
// token is issued: deactivated accounts cannot log in.
const AuthRule = `active = true`

// Form rules: M&E staff and org admins manage forms; everyone else sees
// published versions only. Every active staff role (supervisor,
// branch_manager, me, org_admin, donor_readonly) and every active field
// user can therefore read every published version of every form, which the
// manager app needs to show submissions. The XForm file is protected, so
// downloading it needs a file token and passes FormVersionsRead.
const (
	FormsRead  = AnyActiveUser
	FormsWrite = Active + ` && ` + formManager

	FormVersionsRead   = Active + ` && (published = true || ` + formManager + `)`
	FormVersionsCreate = Active + ` && ` + formManager
	// Once published a version is immutable; the guards hook enforces the
	// same for superusers.
	FormVersionsUpdate = Active + ` && ` + formManager + ` && published = false`
	FormVersionsDelete = Active + ` && ` + formManager + ` && published = false`
)

// Submission rules. Create happens only through POST
// /api/obhijatra/v1/submissions (createRule nil); delete is superuser-only.
var (
	SubmissionsRead = Active + ` && (` +
		`(` + isField + ` && submitted_by = @request.auth.id)` +
		` || ` + isOrgAdmin +
		` || (` + staffReader + ` && ` + inScope + `))`
	// Only ReviewFields may change; the guards hook rejects anything else,
	// for superusers too.
	SubmissionsUpdate = Active + ` && ` + staffReviewer + ` && ` + inScope
)

// Device rules: a user sees their own devices. An org admin may still
// write through the records API, but never DeviceTrustFields (and status
// is required), so in practice a device can only be enrolled through POST
// /api/obhijatra/v1/devices/enrol (zero-trust milestone).
var (
	DevicesRead = Active + ` && (` +
		`(` + isField + ` && field_user = @request.auth.id)` +
		` || (` + isStaff + ` && staff_user = @request.auth.id)` +
		` || ` + isOrgAdmin + `)`
	DevicesWrite = OrgAdminOnly
)

// Session rules: rows are written by the server; an org admin may revoke.
var (
	SessionsRead = Active + ` && (` +
		`(` + isField + ` && field_user = @request.auth.id)` +
		` || (` + isStaff + ` && staff_user = @request.auth.id)` +
		` || ` + isOrgAdmin + `)`
	SessionsUpdate = OrgAdminOnly + ` && @request.body.revoked = true`
)

// Login lock rules: rows are written by the server when an account is
// locked; an org admin may unlock early (the guards in package lockout
// allow no other change and no delete, for superusers too).
const (
	LoginLocksRead   = OrgAdminOnly
	LoginLocksUpdate = OrgAdminOnly + ` && @request.body.unlocked = true`
)

// Audit rules: readable by org admins only; no create, update or delete
// rule exists, and the audit hooks reject those for superusers too.
const AuditRead = OrgAdminOnly
