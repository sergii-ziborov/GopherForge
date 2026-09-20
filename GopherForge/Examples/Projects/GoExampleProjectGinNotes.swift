import Foundation

/// A sticky-note board. Notes live in the browser; the app serves the page.
enum GoExampleProjectGinNotes {
    static let notes = GoExample(
        id: "site.notes",
        title: "Sticky notes",
        summary: "A small board you can type on. Notes stay in this browser.",
        takeaway: "A site can be a page plus a little JavaScript. Gin-style "
            + "routes are checked offline while the app serves the files.",
        conceptTags: [GoConcept.stdlibHTTP, GoConcept.stdlibJSON],
        source: """
        package main

        import (
        \t"net/http"

        \t"github.com/gin-gonic/gin"
        )

        func main() {
        \tr := gin.Default()
        \tr.GET("/", ok("text/html; charset=utf-8"))
        \tr.GET("/styles.css", ok("text/css; charset=utf-8"))
        \tr.GET("/app.js", ok("text/javascript; charset=utf-8"))
        \tr.GET("/api/about", func(c *gin.Context) {
        \t\tc.JSON(http.StatusOK, map[string]any{
        \t\t\t"name": "Sticky notes",
        \t\t\t"hint": "Notes stay in this browser.",
        \t\t})
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
        GET /styles.css 200
        GET /app.js 200
        GET /api/about 200

        """,
        extraFiles: GoExampleGinVendor.files(modulePath: "example.com/sites/notes").merging([
            "web/index.html": """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Sticky notes</title>
              <link rel="stylesheet" href="/styles.css">
            </head>
            <body>
              <header>
                <h1>Sticky notes</h1>
                <p id="hint" class="hint">Loading…</p>
              </header>
              <main>
                <form id="composer">
                  <label for="text">A new note</label>
                  <textarea id="text" name="text" rows="3" required placeholder="Write something you will forget otherwise."></textarea>
                  <button type="submit">Pin it</button>
                </form>
                <section id="board" aria-live="polite"></section>
              </main>
              <script src="/app.js"></script>
            </body>
            </html>
            """,
            "web/styles.css": """
            :root { --paper: #fff6bf; --ink: #2b2618; --pin: #c23b22; }
            body {
              margin: 0;
              font-family: "Trebuchet MS", sans-serif;
              background: #2f4a3a;
              color: var(--ink);
            }
            header, main { max-width: 36rem; margin: 0 auto; padding: 1rem; }
            header { color: #e8f0e4; }
            .hint { opacity: 0.8; }
            form, .note {
              background: var(--paper);
              padding: 0.9rem;
              margin-bottom: 0.75rem;
              box-shadow: 0.25rem 0.25rem 0 rgba(0, 0, 0, 0.18);
            }
            textarea, button { width: 100%; box-sizing: border-box; font: inherit; }
            textarea { margin: 0.4rem 0; }
            button {
              background: var(--pin);
              color: white;
              border: 0;
              padding: 0.5rem;
            }
            .note header { color: inherit; padding: 0; display: flex; justify-content: space-between; }
            .note button { width: auto; background: transparent; color: var(--pin); }
            """,
            "web/app.js": """
            const key = "gopherforge.sticky-notes";
            const board = document.getElementById("board");
            const form = document.getElementById("composer");
            const field = document.getElementById("text");

            function load() {
              try {
                return JSON.parse(localStorage.getItem(key) || "[]");
              } catch (error) {
                return [];
              }
            }

            function save(notes) {
              localStorage.setItem(key, JSON.stringify(notes));
            }

            function render() {
              const notes = load();
              board.innerHTML = "";
              notes.forEach((note, index) => {
                const article = document.createElement("article");
                article.className = "note";
                article.innerHTML =
                  "<header><span>Note " + (index + 1) + "</span></header><p></p>";
                article.querySelector("p").textContent = note;
                const remove = document.createElement("button");
                remove.type = "button";
                remove.textContent = "Unpin";
                remove.addEventListener("click", () => {
                  const next = load().filter((_, position) => position !== index);
                  save(next);
                  render();
                });
                article.querySelector("header").appendChild(remove);
                board.appendChild(article);
              });
            }

            form.addEventListener("submit", (event) => {
              event.preventDefault();
              const text = field.value.trim();
              if (!text) return;
              const notes = load();
              notes.unshift(text);
              save(notes);
              field.value = "";
              render();
            });

            render();
            fetch("/api/about")
              .then((response) => response.json())
              .then((body) => {
                const hint = document.getElementById("hint");
                if (hint) hint.textContent = body.hint;
              });
            """,
            "web/api/about.json": """
            {"name":"Sticky notes","hint":"Notes stay in this browser. Unpin one to throw it away."}
            """,
        ] as [String: String], uniquingKeysWith: { _, incoming in incoming })
    )
}
