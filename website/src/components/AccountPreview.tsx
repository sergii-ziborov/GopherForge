import Link from "next/link";
export function AccountPreview({ mode }: { mode: "login" | "register" }) {
  const register = mode === "register";
  return (
    <div className="page account-page">
      <section className="account-intro">
        <p className="eyebrow">GOPHERFORGE MEMBERS · COMING SOON</p>
        <h1>
          {register ? "Your next chapter." : "Welcome back."}
          <br />
          <em>One reading list.</em>
        </h1>
        <p>
          Personal news collections and member source access are planned.
          Lessons, interview guides and licensed community articles are readable
          now.
        </p>
        <ul>
          <li>Continue already saves your study place in this browser.</li>
          <li>Course access does not require an account.</li>
          <li>Web and native progress are currently stored separately.</li>
        </ul>
        <Link href="/learn" className="text-link">
          Continue learning without an account →
        </Link>
      </section>
      <section className="account-card">
        <span className="release-badge muted">DESIGN PREVIEW · NOT ACTIVE</span>
        <h2>{register ? "Create an account" : "Log in"}</h2>
        <p>
          This is a preview. Registration and login are not connected yet. No
          credentials are collected or stored.
        </p>
        <form aria-label={register ? "Registration preview" : "Login preview"}>
          <fieldset disabled>
            <legend className="sr-only">Account service coming soon</legend>
            {register && (
              <label>
                Your name
                <input type="text" placeholder="Your name" autoComplete="off" />
              </label>
            )}
            <label>
              Email address
              <input
                type="email"
                placeholder="you@example.com"
                autoComplete="off"
              />
            </label>
            <label>
              Password
              <input
                type="password"
                placeholder="Available when accounts open"
                autoComplete="off"
              />
            </label>
            <button className="button" type="button">
              {register ? "Registration" : "Login"} coming soon
            </button>
          </fieldset>
        </form>
        <p className="small-note">
          {register ? "Already exploring?" : "New to GopherForge?"}{" "}
          <Link href={register ? "/login" : "/register"}>
            {register ? "View login preview" : "View registration preview"}
          </Link>
        </p>
        <Link href="/news/feed">← Back to the community feed</Link>
      </section>
    </div>
  );
}
