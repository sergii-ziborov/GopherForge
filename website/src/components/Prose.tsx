import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Code } from "./Code";
export function Prose({ children }: { children: string }) {
  return (
    <div className="prose">
      <Markdown
        remarkPlugins={[remarkGfm]}
        components={{
          table: ({ children }) => (
            <div
              className="prose-table-scroll"
              role="region"
              aria-label="Scrollable comparison table"
              tabIndex={0}
            >
              <table>{children}</table>
            </div>
          ),
          pre: ({ children }) => <>{children}</>,
          code: ({ children, className }) =>
            className || String(children).includes("\n") ? (
              <Code
                code={String(children).replace(/\n$/, "")}
                language={className?.replace("language-", "") ?? "text"}
              />
            ) : (
              <code>{children}</code>
            ),
        }}
      >
        {children}
      </Markdown>
    </div>
  );
}
