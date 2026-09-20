import Foundation

/// A three-item shop with a cart that lives in the browser.
enum GoExampleProjectGinShop {
    static let shop = GoExample(
        id: "site.shop",
        title: "Tiny shop",
        summary: "A catalogue from JSON, a cart you can fill, and a total.",
        takeaway: "fetch talks to the same host that served the page. That is a real site.",
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
        \tr.GET("/cart", ok("text/html; charset=utf-8"))
        \tr.GET("/styles.css", ok("text/css; charset=utf-8"))
        \tr.GET("/app.js", ok("text/javascript; charset=utf-8"))
        \tr.GET("/api/catalog", func(c *gin.Context) {
        \t\tc.JSON(http.StatusOK, []map[string]any{
        \t\t\t{"id": "mug", "name": "Compiler mug", "price": 12},
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
        GET /cart 200
        GET /styles.css 200
        GET /app.js 200
        GET /api/catalog 200

        """,
        extraFiles: GoExampleGinVendor.files(modulePath: "example.com/sites/shop").merging([
            "web/index.html": """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Tiny shop</title>
              <link rel="stylesheet" href="/styles.css">
            </head>
            <body>
              <header>
                <h1>Tiny shop</h1>
                <nav>
                  <a href="/" aria-current="page">Shelf</a>
                  <a href="/cart">Cart <span id="count">0</span></a>
                </nav>
              </header>
              <main id="shelf">Loading the shelf…</main>
              <script src="/app.js"></script>
            </body>
            </html>
            """,
            "web/cart.html": """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Cart · Tiny shop</title>
              <link rel="stylesheet" href="/styles.css">
            </head>
            <body>
              <header>
                <h1>Your cart</h1>
                <nav>
                  <a href="/">Shelf</a>
                  <a href="/cart" aria-current="page">Cart</a>
                </nav>
              </header>
              <main>
                <ul id="lines"></ul>
                <p id="total">Total: 0</p>
                <button id="clear" type="button">Empty the cart</button>
              </main>
              <script src="/app.js"></script>
            </body>
            </html>
            """,
            "web/styles.css": """
            :root { --ink: #102033; --paper: #f7f1e8; --mark: #0b6e4f; }
            body {
              margin: 0;
              font-family: "Avenir Next", "Segoe UI", sans-serif;
              background: var(--paper);
              color: var(--ink);
            }
            header, main { max-width: 36rem; margin: 0 auto; padding: 1rem; }
            nav { display: flex; gap: 1rem; }
            nav a { color: var(--mark); }
            .card {
              background: white;
              border: 1px solid #d9d1c4;
              padding: 0.85rem;
              margin-bottom: 0.7rem;
            }
            button {
              background: var(--mark);
              color: white;
              border: 0;
              padding: 0.45rem 0.75rem;
            }
            """,
            "web/app.js": """
            const key = "gopherforge.tiny-shop";

            function cart() {
              try {
                return JSON.parse(localStorage.getItem(key) || "{}");
              } catch (error) {
                return {};
              }
            }

            function save(next) {
              localStorage.setItem(key, JSON.stringify(next));
              const count = Object.values(next).reduce((sum, n) => sum + n, 0);
              const badge = document.getElementById("count");
              if (badge) badge.textContent = String(count);
            }

            function add(id) {
              const next = cart();
              next[id] = (next[id] || 0) + 1;
              save(next);
            }

            async function catalog() {
              const response = await fetch("/api/catalog");
              return response.json();
            }

            async function renderShelf() {
              const shelf = document.getElementById("shelf");
              if (!shelf) return;
              const items = await catalog();
              shelf.innerHTML = "";
              items.forEach((item) => {
                const card = document.createElement("article");
                card.className = "card";
                card.innerHTML = "<h2></h2><p></p>";
                card.querySelector("h2").textContent = item.name + " · " + item.price;
                card.querySelector("p").textContent = item.blurb;
                const button = document.createElement("button");
                button.type = "button";
                button.textContent = "Add to cart";
                button.addEventListener("click", () => add(item.id));
                card.appendChild(button);
                shelf.appendChild(card);
              });
              save(cart());
            }

            async function renderCart() {
              const lines = document.getElementById("lines");
              if (!lines) return;
              const items = await catalog();
              const held = cart();
              lines.innerHTML = "";
              let total = 0;
              items.forEach((item) => {
                const count = held[item.id] || 0;
                if (!count) return;
                total += count * item.price;
                const row = document.createElement("li");
                row.textContent = count + " × " + item.name + " = " + count * item.price;
                lines.appendChild(row);
              });
              document.getElementById("total").textContent = "Total: " + total;
              const clear = document.getElementById("clear");
              if (clear) {
                clear.addEventListener("click", () => {
                  save({});
                  renderCart();
                });
              }
            }

            save(cart());
            renderShelf();
            renderCart();
            """,
            "web/api/catalog.json": """
            [
              {"id":"mug","name":"Compiler mug","price":12,"blurb":"Keeps a build warm."},
              {"id":"pin","name":"Gopher pin","price":4,"blurb":"Small, enamel, slightly smug."},
              {"id":"book","name":"Effective notes","price":18,"blurb":"Blank pages. You bring the Go."}
            ]
            """,
        ] as [String: String], uniquingKeysWith: { _, incoming in incoming })
    )
}
