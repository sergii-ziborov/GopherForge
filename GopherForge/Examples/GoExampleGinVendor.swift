import Foundation

/// A small, offline `github.com/gin-gonic/gin` the site examples vendor.
///
/// Real Gin pulls a tree of modules this app cannot download. The methods these
/// examples call — `Default`, `GET`, `String`, `JSON`, `Data`, `Run` — are the
/// ones people write first, and they are enough to prove a route table. `Run`
/// walks that table with `httptest` rather than binding a port: the sandbox
/// has no sockets. The app then serves the same pages on this device.
enum GoExampleGinVendor {
    static let modulePath = "github.com/gin-gonic/gin"
    static let version = "v0.0.0-gopherforge-preview"

    static func files(modulePath siteModule: String) -> [String: String] {
        [
            "go.mod": """
            module \(siteModule)

            go \(GoLanguage.declaredModuleVersion)

            require \(modulePath) \(version)

            """,
            "vendor/modules.txt": """
            # \(modulePath) \(version)
            ## explicit
            \(modulePath)

            """,
            "vendor/\(modulePath)/README.md": """
            # Gin-compatible preview subset

            This is a small offline implementation of the Gin methods used by
            these examples, not the upstream Gin distribution. `Run` checks
            registered routes with `httptest` because the Go sandbox has no
            sockets. GopherForge serves the matching web files on localhost.
            """,
            "vendor/\(modulePath)/gin.go": source,
        ]
    }

    private static let source = """
    package gin

    import (
    \t"encoding/json"
    \t"fmt"
    \t"net/http"
    \t"net/http/httptest"
    \t"strings"
    )

    type HandlerFunc func(*Context)

    type Engine struct {
    \troutes []route
    }

    type route struct {
    \tmethod, path string
    \thandler      HandlerFunc
    }

    type Context struct {
    \tWriter  http.ResponseWriter
    \tRequest *http.Request
    }

    func Default() *Engine { return New() }

    func New() *Engine { return &Engine{} }

    func (engine *Engine) GET(path string, handlers ...HandlerFunc) {
    \tengine.add(http.MethodGet, path, handlers)
    }

    func (engine *Engine) POST(path string, handlers ...HandlerFunc) {
    \tengine.add(http.MethodPost, path, handlers)
    }

    func (engine *Engine) add(method, path string, handlers []HandlerFunc) {
    \tif len(handlers) == 0 {
    \t\treturn
    \t}
    \tengine.routes = append(engine.routes, route{method: method, path: path, handler: handlers[0]})
    }

    func (c *Context) Header(key, value string) {
    \tc.Writer.Header().Set(key, value)
    }

    func (c *Context) String(code int, format string, values ...any) {
    \tc.Header("Content-Type", "text/plain; charset=utf-8")
    \tc.Writer.WriteHeader(code)
    \tfmt.Fprintf(c.Writer, format, values...)
    }

    func (c *Context) Data(code int, contentType string, data []byte) {
    \tif contentType != "" {
    \t\tc.Header("Content-Type", contentType)
    \t}
    \tc.Writer.WriteHeader(code)
    \t_, _ = c.Writer.Write(data)
    }

    func (c *Context) JSON(code int, obj any) {
    \tc.Header("Content-Type", "application/json; charset=utf-8")
    \tc.Writer.WriteHeader(code)
    \t_ = json.NewEncoder(c.Writer).Encode(obj)
    }

    func (c *Context) Query(key string) string {
    \treturn c.Request.URL.Query().Get(key)
    }

    // Run cannot listen: WASI has no sockets. It exercises every registered
    // route with httptest. The Swift host serves the preview files separately.
    func (engine *Engine) Run(addr ...string) error {
    \thost := "127.0.0.1:8080"
    \tif len(addr) > 0 && addr[0] != "" {
    \t\thost = addr[0]
    \t\tif strings.HasPrefix(host, ":") {
    \t\t\thost = "127.0.0.1" + host
    \t\t}
    \t}
    \tfmt.Printf("Checking Gin routes for %s (host preview serves files)\\n", host)
    \tfor _, item := range engine.routes {
    \t\trec := httptest.NewRecorder()
    \t\treq := httptest.NewRequest(item.method, item.path, nil)
    \t\titem.handler(&Context{Writer: rec, Request: req})
    \t\tcode := rec.Code
    \t\tif code == 0 {
    \t\t\tcode = http.StatusOK
    \t\t}
    \t\tfmt.Printf("%s %s %d\\n", item.method, item.path, code)
    \t}
    \treturn nil
    }
    """
}
