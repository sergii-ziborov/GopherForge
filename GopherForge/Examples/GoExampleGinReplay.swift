import Foundation

/// Explicit educational adapter: real handlers, bounded request replay, no sockets.
enum GoExampleGinReplay {
    static let source = """
    package gin

    import (
        "encoding/json"
        "fmt"
        "io"
        "net/http"
        "net/http/httptest"
        "os"
        "strings"
    )

    type H map[string]any

    func (e *Engine) PUT(path string, handlers ...HandlerFunc) { e.add("PUT", path, handlers) }
    func (e *Engine) PATCH(path string, handlers ...HandlerFunc) { e.add("PATCH", path, handlers) }
    func (e *Engine) DELETE(path string, handlers ...HandlerFunc) { e.add("DELETE", path, handlers) }
    func (c *Context) Param(key string) string { return c.params[key] }
    func (c *Context) ShouldBindJSON(value any) error {
        return json.NewDecoder(io.LimitReader(c.Request.Body, 32769)).Decode(value)
    }

    func (e *Engine) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
        actual := strings.Split(strings.Trim(request.URL.Path, "/"), "/")
        for _, route := range e.routes {
            expected := strings.Split(strings.Trim(route.path, "/"), "/")
            if route.method != request.Method || len(actual) != len(expected) { continue }
            params := map[string]string{}
            match := true
            for i, part := range expected {
                if strings.HasPrefix(part, ":") { params[strings.TrimPrefix(part, ":")] = actual[i]
                } else if part != actual[i] { match = false; break }
            }
            if match { route.handler(&Context{Writer: writer, Request: request, params: params}); return }
        }
        http.NotFound(writer, request)
    }

    type offlineRequest struct {
        Method string `json:"method"`
        Path string `json:"path"`
        Body string `json:"body"`
        Headers map[string]string `json:"headers"`
    }
    type offlineResponse struct {
        Status int `json:"status"`
        Body string `json:"body"`
        Headers map[string]string `json:"headers"`
    }

    func (e *Engine) runReplay() (bool, error) {
        data, err := os.ReadFile("/sandbox/.gopherforge-http.json")
        if os.IsNotExist(err) { return false, nil }
        if err != nil { return true, err }
        if len(data) > 2*1024*1024 { return true, fmt.Errorf("offline history exceeds 2 MiB") }
        var requests []offlineRequest
        if err := json.Unmarshal(data, &requests); err != nil { return true, err }
        if len(requests) < 1 || len(requests) > 65 { return true, fmt.Errorf("invalid offline request count") }
        var response offlineResponse
        for _, item := range requests {
            if len(item.Body) > 32768 { return true, fmt.Errorf("offline request exceeds 32 KiB") }
            request := httptest.NewRequest(item.Method, item.Path, strings.NewReader(item.Body))
            for key, value := range item.Headers { request.Header.Set(key, value) }
            recorder := httptest.NewRecorder()
            e.ServeHTTP(recorder, request)
            if recorder.Body.Len() > 262144 { return true, fmt.Errorf("offline response exceeds 256 KiB") }
            headers := map[string]string{}
            for key := range recorder.Header() { headers[key] = recorder.Header().Get(key) }
            response = offlineResponse{Status: recorder.Code, Body: recorder.Body.String(), Headers: headers}
        }
        encoded, err := json.Marshal(response)
        if err != nil { return true, err }
        return true, os.WriteFile("/sandbox/.gopherforge-response.json", encoded, 0600)
    }
    """
}
