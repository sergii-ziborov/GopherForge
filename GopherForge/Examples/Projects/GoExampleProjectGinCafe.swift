import Foundation

/// A three-page café site: home, about, and a health JSON the page fetches.
enum GoExampleProjectGinCafe {
    static let cafe = GoExample(
        id: "site.cafe",
        title: "Gopher Café",
        summary: "A small site: two pages, Gin-style routes, CSS and health JSON.",
        takeaway: "The offline Gin subset checks each route with httptest. "
            + "The app serves matching web files on this device.",
        conceptTags: [GoConcept.stdlibHTTP, GoConcept.importPath],
        source: """
        package main

        import (
        \t"net/http"

        \t"github.com/gin-gonic/gin"
        )

        func main() {
        \t// Pages live in web/. Run exercises the routes; the app serves them.
        \tr := gin.Default()
        \tr.GET("/", ok("text/html; charset=utf-8"))
        \tr.GET("/about", ok("text/html; charset=utf-8"))
        \tr.GET("/styles.css", ok("text/css; charset=utf-8"))
        \tr.GET("/app.js", ok("text/javascript; charset=utf-8"))
        \tr.GET("/api/health", func(c *gin.Context) {
        \t\tc.JSON(http.StatusOK, map[string]any{"ok": true, "place": "Gopher Café"})
        \t})
        \t_ = r.Run("127.0.0.1:8080")
        }

        func ok(contentType string) gin.HandlerFunc {
        \treturn func(c *gin.Context) {
        \t\tc.Data(http.StatusOK, contentType, []byte("ok"))
        \t}
        }
        """,
        expectedOutput: """
        Checking Gin routes for 127.0.0.1:8080 (host preview serves files)
        GET / 200
        GET /about 200
        GET /styles.css 200
        GET /app.js 200
        GET /api/health 200

        """,
        extraFiles: GoExampleGinVendor.files(modulePath: "example.com/sites/cafe").merging([
            "web/index.html": """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Gopher Café</title>
              <link rel="stylesheet" href="/styles.css">
            </head>
            <body>
              <header>
                <p class="eyebrow">Gin · localhost</p>
                <h1>Gopher Café</h1>
                <nav>
                  <a href="/" aria-current="page">Menu</a>
                  <a href="/about">About</a>
                </nav>
              </header>
              <main>
                <p id="greeting">A quiet table, a strong brew, and a compiler that runs on this device.</p>
                <button id="next" type="button">Another table</button>
                <ul class="menu">
                  <li><strong>Compile</strong> — black, no sugar</li>
                  <li><strong>Vet</strong> — with a slice of lemon</li>
                  <li><strong>Test</strong> — poured over ice</li>
                </ul>
                <p class="status" id="status">Asking the kitchen…</p>
              </main>
              <script src="/app.js"></script>
            </body>
            </html>
            """,
            "web/about.html": """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>About · Gopher Café</title>
              <link rel="stylesheet" href="/styles.css">
            </head>
            <body>
              <header>
                <p class="eyebrow">Gin · localhost</p>
                <h1>About the café</h1>
                <nav>
                  <a href="/">Menu</a>
                  <a href="/about" aria-current="page">About</a>
                </nav>
              </header>
              <main>
                <p>These pages are ordinary HTML, CSS and JavaScript. An offline Gin
                subset checks their routes; this device serves the files on localhost.</p>
                <p>Hours: whenever you tap Run.</p>
              </main>
            </body>
            </html>
            """,
            "web/styles.css": """
            :root {
              --ink: #1c1916;
              --paper: #f4efe6;
              --accent: #c45c26;
            }
            body {
              margin: 0;
              font-family: Georgia, "Times New Roman", serif;
              background: var(--paper);
              color: var(--ink);
            }
            header, main { max-width: 32rem; margin: 0 auto; padding: 1.25rem; }
            .eyebrow { letter-spacing: 0.12em; text-transform: uppercase; font-size: 0.7rem; }
            nav { display: flex; gap: 1rem; margin: 0.75rem 0 0; }
            nav a { color: var(--accent); }
            nav a[aria-current="page"] { font-weight: bold; }
            button {
              background: var(--accent);
              color: white;
              border: 0;
              padding: 0.55rem 0.9rem;
              border-radius: 999px;
            }
            .menu { padding-left: 1.1rem; }
            .status { color: #5c5348; font-size: 0.9rem; }
            """,
            "web/app.js": """
            const greetings = [
              "A quiet table, a strong brew, and a compiler that runs on this device.",
              "Sit anywhere. The kitchen is this phone.",
              "The special today is a passing test.",
            ];
            let index = 0;
            const greeting = document.getElementById("greeting");
            const button = document.getElementById("next");
            if (button && greeting) {
              button.addEventListener("click", () => {
                index = (index + 1) % greetings.length;
                greeting.textContent = greetings[index];
              });
            }
            const status = document.getElementById("status");
            if (status) {
              fetch("/api/health")
                .then((response) => response.json())
                .then((body) => {
                  status.textContent = body.ok
                    ? "Kitchen is open · " + body.place
                    : "Kitchen is closed";
                })
                .catch(() => {
                  status.textContent = "Could not reach /api/health";
                });
            }
            """,
            "web/api/health.json": """
            {"ok":true,"place":"Gopher Café"}
            """,
        ] as [String: String], uniquingKeysWith: { _, incoming in incoming })
    )
}
