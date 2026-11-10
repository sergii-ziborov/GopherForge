"use client";
import { useMemo, useState } from "react";
export type FileAction =
  "new-file" | "new-folder" | "rename" | "duplicate" | "delete" | "download";
export function ProjectTree({
  paths,
  active,
  readOnly,
  onOpen,
  onAction,
  onMove,
}: {
  paths: string[];
  active: string;
  readOnly: boolean;
  onOpen: (p: string) => void;
  onAction: (a: FileAction, path: string) => void;
  onMove: (from: string, folder: string) => void;
}) {
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set()),
    [query, setQuery] = useState(""),
    [menu, setMenu] = useState<string | null>(null),
    [drop, setDrop] = useState<string | null>(null);
  const tree = useMemo(() => {
    const folders = new Set<string>();
    for (const path of paths) {
      const parts = path.split("/");
      parts.pop();
      while (parts.length) {
        folders.add(parts.join("/"));
        parts.pop();
      }
    }
    return [...folders]
      .map((path) => ({ path, folder: true }))
      .concat(paths.map((path) => ({ path, folder: false })))
      .sort((a, b) => {
        const x = a.path.split("/"),
          y = b.path.split("/");
        for (let i = 0; i < Math.min(x.length, y.length); i++) {
          if (x[i] === y[i]) continue;
          const xf = i < x.length - 1 || a.folder,
            yf = i < y.length - 1 || b.folder;
          if (xf !== yf) return xf ? -1 : 1;
          return x[i].localeCompare(y[i]);
        }
        return x.length - y.length;
      });
  }, [paths]);
  const rows = tree.filter(
    (n) =>
      (!query ||
        n.path.toLowerCase().includes(query.toLowerCase()) ||
        (n.folder &&
          paths.some(
            (p) =>
              p.startsWith(n.path + "/") &&
              p.toLowerCase().includes(query.toLowerCase()),
          ))) &&
      (!query ? ![...collapsed].some((p) => n.path.startsWith(p + "/")) : true),
  );
  function toggle(path: string) {
    setCollapsed((old) => {
      const next = new Set(old);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  }
  return (
    <div
      className="gf-tree"
      onDragOver={(e) => {
        if (!readOnly) {
          e.preventDefault();
          setDrop("");
        }
      }}
      onDrop={(e) => {
        e.preventDefault();
        setDrop(null);
        const from = e.dataTransfer.getData("application/x-gopherforge-path");
        if (from && !readOnly) onMove(from, "");
      }}
    >
      <label className="gf-file-search">
        <span className="gf-sr-only">Find file</span>
        <span aria-hidden="true">⌕</span>
        <input
          type="search"
          placeholder="Find file…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </label>
      <div className="gf-tree-heading">
        <span>EXPLORER</span>
        <button
          title="New file"
          aria-label="New file"
          disabled={readOnly}
          onClick={() => onAction("new-file", "")}
        >
          ＋
        </button>
        <button
          title="New folder"
          aria-label="New folder"
          disabled={readOnly}
          onClick={() => onAction("new-folder", "")}
        >
          ▱
        </button>
      </div>
      <div
        role="tree"
        aria-label="Project files"
        className={drop === "" ? "gf-tree-root-target" : ""}
      >
        {rows.map((node, index) => {
          const depth = node.path.split("/").length - 1,
            open = !collapsed.has(node.path),
            selected = node.path === active && !node.folder;
          return (
            <div
              key={node.path}
              className={`gf-tree-row ${selected ? "gf-tree-selected" : ""} ${drop === node.path ? "gf-tree-drop" : ""}`}
              role="treeitem"
              aria-level={depth + 1}
              aria-expanded={node.folder ? open : undefined}
              aria-selected={selected}
              tabIndex={selected || index === 0 ? 0 : -1}
              style={{ paddingLeft: 10 + depth * 14 }}
              title={node.path}
              draggable={!readOnly && node.path !== "main.go"}
              onDragStart={(e) => {
                e.dataTransfer.setData(
                  "application/x-gopherforge-path",
                  node.path,
                );
                e.dataTransfer.effectAllowed = "move";
              }}
              onDragOver={(e) => {
                if (node.folder && !readOnly) {
                  e.preventDefault();
                  e.stopPropagation();
                  setDrop(node.path);
                }
              }}
              onDragLeave={() => setDrop(null)}
              onDrop={(e) => {
                if (!node.folder) return;
                e.preventDefault();
                e.stopPropagation();
                setDrop(null);
                const from = e.dataTransfer.getData(
                  "application/x-gopherforge-path",
                );
                if (from && !readOnly) onMove(from, node.path);
              }}
              onClick={() => {
                if (node.folder) toggle(node.path);
                else onOpen(node.path);
              }}
              onKeyDown={(e) => {
                const all = [
                  ...e.currentTarget.parentElement!.querySelectorAll<HTMLElement>(
                    '[role="treeitem"]',
                  ),
                ];
                if (e.key === "ArrowDown" || e.key === "ArrowUp") {
                  e.preventDefault();
                  all[
                    Math.max(
                      0,
                      Math.min(
                        all.length - 1,
                        index + (e.key === "ArrowDown" ? 1 : -1),
                      ),
                    )
                  ]?.focus();
                } else if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  node.folder ? toggle(node.path) : onOpen(node.path);
                } else if (e.key === "F2" && !readOnly) {
                  e.preventDefault();
                  onAction("rename", node.path);
                } else if (e.key === "ArrowLeft" && node.folder && open) {
                  e.preventDefault();
                  toggle(node.path);
                } else if (e.key === "ArrowRight" && node.folder && !open) {
                  e.preventDefault();
                  toggle(node.path);
                }
              }}
            >
              <span className="gf-file-symbol" aria-hidden="true">
                {node.folder
                  ? open
                    ? "⌄ ▱"
                    : "› ▱"
                  : node.path.endsWith(".go")
                    ? "‹›"
                    : node.path.endsWith(".mod") || node.path.endsWith(".sum")
                      ? "≡"
                      : "▤"}
              </span>
              <span className="gf-file-name">
                {node.path.split("/").at(-1)}
              </span>
              <button
                className="gf-file-more"
                aria-label={`Actions for ${node.path}`}
                aria-expanded={menu === node.path}
                onClick={(e) => {
                  e.stopPropagation();
                  setMenu(menu === node.path ? null : node.path);
                }}
              >
                ⋯
              </button>
              {menu === node.path && (
                <div
                  className="gf-file-menu"
                  role="menu"
                  onClick={(e) => e.stopPropagation()}
                  onKeyDown={(e) => {
                    if (e.key === "Escape") setMenu(null);
                  }}
                >
                  {(node.folder
                    ? [
                        ["new-file", "New file inside"],
                        ["new-folder", "New folder inside"],
                        ["rename", "Rename / move"],
                        ["delete", "Delete contents"],
                      ]
                    : [
                        ["rename", "Rename / move"],
                        ["duplicate", "Duplicate"],
                        ["download", "Download file"],
                        ["delete", "Delete file"],
                      ]
                  ).map(([action, label]) => (
                    <button
                      role="menuitem"
                      key={action}
                      disabled={
                        (readOnly && action !== "download") ||
                        (node.path === "main.go" &&
                          (action === "rename" || action === "delete"))
                      }
                      onClick={() => {
                        setMenu(null);
                        onAction(action as FileAction, node.path);
                      }}
                    >
                      {label}
                    </button>
                  ))}
                  <button
                    role="menuitem"
                    onClick={() => {
                      void navigator.clipboard.writeText(node.path);
                      setMenu(null);
                    }}
                  >
                    Copy path
                  </button>
                  <button role="menuitem" onClick={() => setMenu(null)}>
                    Close menu
                  </button>
                </div>
              )}
            </div>
          );
        })}
        {!rows.length && <p className="gf-muted">No matching files</p>}
      </div>
    </div>
  );
}
