package trustcheck

import (
	"crypto/x509"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestTLSVerificationControls(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "ready")
	}))
	defer server.Close()

	cases := []struct {
		name      string
		change    func(*http.Transport)
		wantError bool
		errorKind string
	}{
		{name: "trusted test certificate"},
		{
			name: "unknown authority",
			change: func(tr *http.Transport) {
				tr.TLSClientConfig.RootCAs = x509.NewCertPool()
			},
			wantError: true,
			errorKind: "authority",
		},
		{
			name: "wrong hostname",
			change: func(tr *http.Transport) {
				tr.TLSClientConfig.ServerName = "wrong.invalid"
			},
			wantError: true,
			errorKind: "hostname",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			tr := server.Client().Transport.(*http.Transport).Clone()
			tr.TLSClientConfig = tr.TLSClientConfig.Clone()
			if tc.change != nil {
				tc.change(tr)
			}
			defer tr.CloseIdleConnections()
			client := &http.Client{Transport: tr, Timeout: 3 * time.Second}
			response, err := client.Get(server.URL)
			if response != nil {
				defer response.Body.Close()
			}
			if (err != nil) != tc.wantError {
				t.Fatalf("error = %v; wantError = %v", err, tc.wantError)
			}
			if tc.errorKind == "authority" {
				var target x509.UnknownAuthorityError
				if !errors.As(err, &target) {
					t.Fatalf("want unknown authority, got %v", err)
				}
			}
			if tc.errorKind == "hostname" {
				var target x509.HostnameError
				if !errors.As(err, &target) {
					t.Fatalf("want hostname mismatch, got %v", err)
				}
			}
		})
	}
}
