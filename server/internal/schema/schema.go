// Package schema holds the names, roles and row-level API rules of
// Obhijatra's data model, so that migrations, hooks, routes and tests all
// use one definition.
package schema

import "regexp"

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
	Audit        = "audit"

	// Superusers is PocketBase's built-in superuser collection.
	Superusers = "_superusers"
)

// CoreCollections cannot be renamed or deleted, because the API rules,
// hooks and routes refer to them by name.
var CoreCollections = []string{
	Settings, Locations, FieldUsers, StaffUsers, Forms, FormVersions,
	Submissions, Devices, Sessions, Audit,
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

	// MaxXMLSize caps an XForm definition or a submission instance.
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

// Device values.
const (
	DeviceActive  = "active"
	DeviceRevoked = "revoked"

	AttestationNone     = "none"
	AttestationSoftware = "software"
	AttestationHardware = "hardware"
)

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

	// staffReviewer: staff roles that may change a submission's review state.
	staffReviewer = `(` + isStaff + ` && (@request.auth.role = "` + RoleSupervisor +
		`" || @request.auth.role = "` + RoleBranchManager + `"))`

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

// Location rules: the organisation tree is not personal data.
const (
	LocationsRead  = AnyActiveUser
	LocationsWrite = OrgAdminOnly
)

// userSelfUpdate lets users change their own name and password but none of
// the fields that decide what they can see.
func userSelfUpdate(collection string) string {
	return `(@request.auth.collectionName = "` + collection + `" && id = @request.auth.id` +
		` && @request.body.role:isset = false` +
		` && @request.body.location:isset = false` +
		` && @request.body.location_path:isset = false` +
		` && @request.body.active:isset = false` +
		` && @request.body.email:isset = false` +
		` && @request.body.verified:isset = false)`
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

// Form rules: field users see published versions only.
const (
	FormsRead  = AnyActiveUser
	FormsWrite = OrgAdminOnly

	FormVersionsRead   = Active + ` && (published = true || ` + isOrgAdmin + `)`
	FormVersionsCreate = OrgAdminOnly
	// Once published a version is immutable; the guards hook enforces the
	// same for superusers.
	FormVersionsUpdate = OrgAdminOnly + ` && published = false`
	FormVersionsDelete = OrgAdminOnly + ` && published = false`
)

// Submission rules. Create happens only through POST
// /api/obhijatra/v1/submissions (createRule nil); delete is superuser-only.
var (
	SubmissionsRead = Active + ` && (` +
		`(` + isField + ` && submitted_by = @request.auth.id)` +
		` || ` + isOrgAdmin +
		` || (` + staffReader + ` && ` + inScope + `))`
	// Only review_state may change; the guards hook rejects anything else,
	// for superusers too.
	SubmissionsUpdate = Active + ` && (` + isOrgAdmin + ` || (` + staffReviewer + ` && ` + inScope + `))`
)

// Device rules: a user sees their own devices; enrolment is an org-admin
// act (the device-signing ceremony arrives with the zero-trust milestone).
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

// Audit rules: readable by org admins only; no create, update or delete
// rule exists, and the audit hooks reject those for superusers too.
const AuditRead = OrgAdminOnly
