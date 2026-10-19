import { codeToHtml } from "shiki";
import { CodeActions } from "./CodeActions";
const languages = new Set([
  "go",
  "bash",
  "sh",
  "shell",
  "yaml",
  "json",
  "dockerfile",
  "text",
  "sql",
]);
export async function Code({
  code,
  language = "go",
  actions = true,
}: {
  code: string;
  language?: string;
  actions?: boolean;
}) {
  const lang = languages.has(language.toLowerCase())
    ? language.toLowerCase()
    : "text";
  const html = await codeToHtml(code, {
    lang: lang === "shell" || lang === "sh" ? "bash" : lang,
    theme: "github-dark",
  });
  return (
    <div className="code-block">
      <div className="code-label">
        <span>{lang}</span>
        {actions ? <CodeActions code={code} /> : null}
      </div>
      <div className="code-scroll" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  );
}
