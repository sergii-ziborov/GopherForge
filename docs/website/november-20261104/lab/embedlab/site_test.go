package embedlab

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRoutesStaySeparate(t *testing.T) {
	h := Handler()
	for _, x := range []struct {
		path   string
		status int
		mime   string
	}{{"/", 200, "text/html"}, {"/projects/42", 200, "text/html"}, {"/assets/app.js", 200, "javascript"}, {"/api/status", 200, "application/json"}, {"/assets/missing.js", 404, ""}, {"/api/missing", 404, ""}, {"/missing.js", 404, ""}, {"/assets/", 404, ""}} {
		r := httptest.NewRecorder()
		h.ServeHTTP(r, httptest.NewRequest("GET", x.path, nil))
		if r.Code != x.status || x.mime != "" && !strings.Contains(r.Header().Get("Content-Type"), x.mime) {
			t.Fatal(x, r.Code, r.Header())
		}
	}
}
func TestHeadAndMethod(t *testing.T) {
	h := Handler()
	r := httptest.NewRecorder()
	h.ServeHTTP(r, httptest.NewRequest("HEAD", "/projects/42", nil))
	if r.Code != 200 || r.Body.Len() != 0 {
		t.Fatal(r.Code, r.Body)
	}
	r = httptest.NewRecorder()
	h.ServeHTTP(r, httptest.NewRequest("POST", "/projects/42", nil))
	if r.Code != 405 {
		t.Fatal(r.Code)
	}
}
