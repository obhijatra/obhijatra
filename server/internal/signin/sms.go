package signin

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"syscall"
	"time"
	"unicode"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
)

// The placeholders an org admin can put in the SMS provider's address,
// body and header values. Each is filled in with the escaping its place
// needs (URL, JSON or form encoding).
const (
	PlaceholderPhone       = "{phone}"        // +8801712345678
	PlaceholderPhoneDigits = "{phone_digits}" // 8801712345678
	PlaceholderMessage     = "{message}"
	PlaceholderSecret      = "{secret}"
)

// Body formats for POST requests.
const (
	ContentJSON = "json" // application/json
	ContentForm = "form" // application/x-www-form-urlencoded
)

// Header is one extra HTTP header sent to the SMS provider.
type Header struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

// SMSGateway is how the server asks the organisation's SMS provider to send
// a message: any provider with a web (HTTPS) interface, described by form.
type SMSGateway struct {
	Method      string   `json:"method"`       // GET or POST
	URL         string   `json:"url"`          // https only; may hold placeholders
	ContentType string   `json:"content_type"` // ContentJSON or ContentForm (POST only)
	Body        string   `json:"body"`         // POST body template
	Headers     []Header `json:"headers"`
	Secret      string   `json:"secret,omitempty"` // API key or token, put where {secret} is
	SuccessText string   `json:"success_text"`     // text the provider's reply must contain, if set

	// secretMissing marks a gateway whose secret was left empty although
	// the stored one cannot be reused (see withStoredSecret).
	secretMissing bool
}

// providerHost is the server name and port of an address template, in
// lower case, or "" if it cannot be read or holds a placeholder.
func providerHost(template string) string {
	u, err := url.Parse(template)
	if err != nil || u.Host == "" || strings.ContainsAny(u.Host, "{}") {
		return ""
	}
	return strings.ToLower(u.Host)
}

// withStoredSecret fills an empty secret with the stored one, but only if
// the message still goes to the same provider server. Otherwise the secret
// must be typed again, so a stolen admin session cannot send the stored
// key to a server of its choosing.
func (g SMSGateway) withStoredSecret(stored SMSGateway) SMSGateway {
	if g.Secret != "" || stored.Secret == "" {
		return g
	}
	if h := providerHost(g.URL); h != "" && h == providerHost(stored.URL) {
		g.Secret = stored.Secret
		return g
	}
	g.secretMissing = true
	return g
}

const (
	maxURL         = 2000
	maxBody        = 5000
	maxHeaders     = 10
	maxHeaderValue = 1000
	maxSecret      = 1000
	maxSuccessText = 200
	maxReply       = 300
)

var headerNamePattern = regexp.MustCompile(`^[A-Za-z0-9-]{1,64}$`)

// forbiddenHeaders are set by the server itself.
var forbiddenHeaders = []string{"host", "content-length", "content-type", "transfer-encoding", "connection"}

func (g SMSGateway) normalised() SMSGateway {
	g.Method = strings.ToUpper(strings.TrimSpace(g.Method))
	if g.Method == "" {
		g.Method = http.MethodPost
	}
	g.URL = strings.TrimSpace(g.URL)
	g.ContentType = strings.ToLower(strings.TrimSpace(g.ContentType))
	if g.Method == http.MethodGet {
		g.ContentType = ""
		g.Body = ""
	} else if g.ContentType == "" {
		g.ContentType = ContentJSON
	}
	g.Body = strings.TrimSpace(g.Body)
	g.Secret = strings.TrimSpace(g.Secret)
	g.SuccessText = strings.TrimSpace(g.SuccessText)
	headers := make([]Header, 0, len(g.Headers))
	for _, h := range g.Headers {
		h.Name, h.Value = strings.TrimSpace(h.Name), strings.TrimSpace(h.Value)
		if h.Name != "" || h.Value != "" {
			headers = append(headers, h)
		}
	}
	g.Headers = headers
	return g
}

// Validate reports every problem with g, keyed by field, in plain words.
// It expects a normalised gateway.
func (g SMSGateway) Validate() FieldErrors {
	errs := FieldErrors{}

	if g.Method != http.MethodGet && g.Method != http.MethodPost {
		errs["method"] = "Choose GET or POST, as your SMS provider's guide says."
	}

	switch {
	case g.URL == "":
		errs["url"] = "Enter the web address your SMS provider gives for sending a message."
	case len(g.URL) > maxURL:
		errs["url"] = fmt.Sprintf("The web address is longer than %d characters.", maxURL)
	default:
		u, err := url.Parse(g.fill(g.URL, samplePhone, "sample", escapeURL))
		switch {
		case err != nil || u.Host == "":
			errs["url"] = "This is not a complete web address. It should start with https://"
		case u.Scheme != "https":
			errs["url"] = "The address must start with https:// so the codes and your key travel encrypted."
		case providerHost(g.URL) == "":
			errs["url"] = "The server name in the address (the part after https://) cannot hold a placeholder."
		}
	}
	if g.secretMissing {
		errs["secret"] = "Type the secret key again: the SMS provider's address changed."
	}

	if g.Method == http.MethodPost {
		switch g.ContentType {
		case ContentJSON:
			if g.Body != "" && !json.Valid([]byte(g.fill(g.Body, samplePhone, "sample", escapeJSON))) {
				errs["body"] = "The message body is not valid JSON. Copy it again from your SMS provider's guide."
			}
		case ContentForm:
		default:
			errs["content_type"] = "Choose JSON or form for the message body, as your SMS provider's guide says."
		}
		if len(g.Body) > maxBody {
			errs.add("body", fmt.Sprintf("The message body is longer than %d characters.", maxBody))
		}
	}

	where := g.URL + " " + g.Body
	if !strings.Contains(where, PlaceholderMessage) {
		errs.add("body", "Put "+PlaceholderMessage+" where the text of the SMS goes (in the address or the body).")
	}
	if !strings.Contains(where, PlaceholderPhone) && !strings.Contains(where, PlaceholderPhoneDigits) {
		errs.add("url", "Put "+PlaceholderPhone+" or "+PlaceholderPhoneDigits+" where the phone number goes (in the address or the body).")
	}

	if len(g.Headers) > maxHeaders {
		errs["headers"] = fmt.Sprintf("At most %d extra headers.", maxHeaders)
	}
	for i, h := range g.Headers {
		key := fmt.Sprintf("headers.%d", i)
		switch {
		case !headerNamePattern.MatchString(h.Name):
			errs[key] = "A header name uses only letters, digits and hyphens, for example Authorization."
		case containsFold(forbiddenHeaders, h.Name):
			errs[key] = "The server sets the " + h.Name + " header itself; remove it."
		case len(h.Value) > maxHeaderValue || strings.ContainsFunc(h.Value, unicode.IsControl):
			errs[key] = "This header value is too long or contains a line break."
		}
	}

	if len(g.Secret) > maxSecret || strings.ContainsFunc(g.Secret, unicode.IsControl) {
		errs["secret"] = "The key is too long or contains a line break."
	}
	if len(g.SuccessText) > maxSuccessText {
		errs["success_text"] = fmt.Sprintf("Keep this under %d characters.", maxSuccessText)
	}
	return errs
}

const samplePhone = "+8801700000000"

type escaper func(string) string

func escapeURL(s string) string { return url.QueryEscape(s) }

func escapeJSON(s string) string {
	b, _ := json.Marshal(s)
	return string(b[1 : len(b)-1])
}

func escapeNone(s string) string { return s }

// fill puts the values in place of the placeholders in template, each
// escaped with esc.
func (g SMSGateway) fill(template, phone, message string, esc escaper) string {
	return strings.NewReplacer(
		PlaceholderPhoneDigits, esc(strings.TrimPrefix(phone, "+")),
		PlaceholderPhone, esc(phone),
		PlaceholderMessage, esc(message),
		PlaceholderSecret, esc(g.Secret),
	).Replace(template)
}

// request builds the HTTP request that sends message to phone.
func (g SMSGateway) request(ctx context.Context, phone, message string) (*http.Request, error) {
	target := g.fill(g.URL, phone, message, escapeURL)

	var body io.Reader
	contentType := ""
	if g.Method == http.MethodPost {
		switch g.ContentType {
		case ContentForm:
			body = strings.NewReader(g.fill(g.Body, phone, message, escapeURL))
			contentType = "application/x-www-form-urlencoded"
		default:
			body = strings.NewReader(g.fill(g.Body, phone, message, escapeJSON))
			contentType = "application/json"
		}
	}

	req, err := http.NewRequestWithContext(ctx, g.Method, target, body)
	if err != nil {
		return nil, errors.New("the SMS provider's address could not be used")
	}
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	req.Header.Set("User-Agent", "obhijatra-server")
	for _, h := range g.Headers {
		req.Header.Set(h.Name, g.fill(h.Value, phone, message, escapeNone))
	}
	return req, nil
}

// SendResult is the outcome of one attempt to send an SMS.
type SendResult struct {
	At     time.Time `json:"at"`
	OK     bool      `json:"ok"`
	Status int       `json:"status"` // the provider's HTTP status; 0 if it did not answer
	Reply  string    `json:"reply"`  // the start of the provider's reply, or what went wrong
}

// SMSTransport carries the requests to SMS providers. It refuses loopback,
// link-local and multicast addresses (cloud metadata services among
// them), so the provider form cannot be used to reach the server itself;
// providers on the organisation's own network are allowed. Tests replace
// it.
var SMSTransport http.RoundTripper = &http.Transport{
	DialContext: (&net.Dialer{
		Timeout: 10 * time.Second,
		Control: refuseInternalAddress,
	}).DialContext,
	TLSHandshakeTimeout:   10 * time.Second,
	ResponseHeaderTimeout: 15 * time.Second,
	MaxIdleConns:          4,
	IdleConnTimeout:       60 * time.Second,
}

func refuseInternalAddress(_, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsInterfaceLocalMulticast() || ip.IsMulticast() || ip.IsUnspecified() {
		return fmt.Errorf("the SMS provider's address %s is not allowed", host)
	}
	return nil
}

// Send asks the provider to send message to phone. It never follows a
// redirect (which could leave HTTPS) and never puts the secret into the
// result.
func (g SMSGateway) Send(ctx context.Context, phone, message string) SendResult {
	res := SendResult{At: time.Now().UTC()}

	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	req, err := g.request(ctx, phone, message)
	if err != nil {
		res.Reply = err.Error()
		return res
	}
	client := &http.Client{
		Transport:     SMSTransport,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	resp, err := client.Do(req)
	if err != nil {
		res.Reply = g.hideSecret(describeSendError(err))
		return res
	}
	defer resp.Body.Close()

	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	res.Status = resp.StatusCode
	// Hide the key before shortening, so no part of it survives the cut.
	res.Reply = printable([]byte(g.hideSecret(string(raw))), maxReply)
	res.OK = resp.StatusCode >= 200 && resp.StatusCode < 300 &&
		(g.SuccessText == "" || bytes.Contains(raw, []byte(g.SuccessText)))
	return res
}

func describeSendError(err error) string {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		err = urlErr.Err // drop the address, which may hold the secret
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "The SMS provider did not answer within 20 seconds."
	}
	return "Could not reach the SMS provider: " + err.Error()
}

// hideSecret removes the secret from text: some providers repeat the key
// in their reply.
func (g SMSGateway) hideSecret(text string) string {
	if len(g.Secret) < 4 {
		return text
	}
	for _, s := range []string{
		g.Secret, escapeURL(g.Secret), escapeJSON(g.Secret),
		base64.StdEncoding.EncodeToString([]byte(g.Secret)),
		base64.RawURLEncoding.EncodeToString([]byte(g.Secret)),
	} {
		text = strings.ReplaceAll(text, s, "[key hidden]")
	}
	return text
}

func printable(raw []byte, max int) string {
	s := strings.Map(func(r rune) rune {
		if r == unicode.ReplacementChar || (unicode.IsControl(r) && r != ' ') {
			return ' '
		}
		return r
	}, string(bytes.ToValidUTF8(raw, nil)))
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > max {
		s = string(r[:max]) + "…"
	}
	return s
}

func containsFold(list []string, s string) bool {
	for _, v := range list {
		if strings.EqualFold(v, s) {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------------

const lastSendKey = "obhijatra.signin.lastSend"

// remember keeps the outcome of the latest send in memory, for the
// settings screen; it is not stored (a restart forgets it).
func remember(app core.App, r SendResult) {
	app.Store().Set(lastSendKey, r)
}

func lastSend(app core.App) *SendResult {
	if r, ok := app.Store().Get(lastSendKey).(SendResult); ok {
		return &r
	}
	return nil
}
