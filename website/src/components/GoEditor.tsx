"use client";
import { useEffect, useRef } from "react";
import { EditorState, Compartment } from "@codemirror/state";
import {
  EditorView,
  Decoration,
  GutterMarker,
  WidgetType,
  gutter,
  keymap,
  lineNumbers,
  highlightActiveLineGutter,
  highlightActiveLine,
  drawSelection,
} from "@codemirror/view";
import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
} from "@codemirror/commands";
import {
  bracketMatching,
  foldGutter,
  indentOnInput,
  StreamLanguage,
  syntaxHighlighting,
  HighlightStyle,
} from "@codemirror/language";
import { tags } from "@lezer/highlight";
import { go } from "@codemirror/legacy-modes/mode/go";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import {
  searchKeymap,
  highlightSelectionMatches,
  openSearchPanel,
} from "@codemirror/search";
import {
  yCollab,
  yUndoManagerKeymap,
  ySyncAnnotation,
} from "y-codemirror.next";
import * as Y from "yjs";
import type { PeerCursor } from "@/lib/playground-identity";
import type { Awareness } from "y-protocols/awareness";
class Breakpoint extends GutterMarker {
  constructor(
    readonly line: number,
    readonly active: boolean,
    readonly toggle: () => void,
  ) {
    super();
  }
  eq(other: Breakpoint) {
    return this.line === other.line && this.active === other.active;
  }
  toDOM() {
    const button = document.createElement("button");
    button.type = "button";
    button.className = this.active
      ? "cm-breakpoint cm-breakpoint-set"
      : "cm-breakpoint";
    button.title = `${this.active ? "Remove" : "Add"} breakpoint at line ${this.line}`;
    button.setAttribute("aria-label", button.title);
    button.onclick = this.toggle;
    button.textContent = "●";
    return button;
  }
}
class PeerCaret extends WidgetType {
  constructor(
    readonly name: string,
    readonly color: string,
  ) {
    super();
  }
  eq(other: PeerCaret) {
    return this.name === other.name && this.color === other.color;
  }
  toDOM() {
    const caret = document.createElement("span");
    caret.className = "gf-peer-caret";
    caret.style.borderColor = this.color;
    const label = document.createElement("span");
    label.className = "gf-peer-name";
    label.style.backgroundColor = this.color;
    label.textContent = this.name;
    caret.append(label);
    caret.setAttribute("aria-label", `${this.name}’s cursor`);
    return caret;
  }
}
const noPeers: PeerCursor[] = [];
export function GoEditor({
  path,
  value,
  readOnly,
  onChange,
  onRun,
  revealLine,
  breakpoints = [],
  debugLine,
  onBreakpoint,
  documentKey = "local",
  text,
  awareness,
  onLimit,
  fontSize = 14,
  wrap = false,
  searchRequest = 0,
  onSelection,
  peerCursors = noPeers,
}: {
  path: string;
  value: string;
  readOnly: boolean;
  onChange: (text: string) => void;
  onRun: () => void;
  revealLine?: number;
  breakpoints?: number[];
  debugLine?: number;
  onBreakpoint?: (line: number) => void;
  documentKey?: string;
  text?: Y.Text;
  awareness?: Awareness;
  onLimit?: () => void;
  fontSize?: number;
  wrap?: boolean;
  searchRequest?: number;
  onSelection?: (anchor: number, head: number) => void;
  peerCursors?: PeerCursor[];
}) {
  const host = useRef<HTMLDivElement>(null),
    view = useRef<EditorView | null>(null),
    callbacks = useRef({ onChange, onRun, onBreakpoint, onLimit, onSelection }),
    config = useRef(new Compartment()),
    debugConfig = useRef(new Compartment()),
    peerConfig = useRef(new Compartment()),
    applying = useRef(false),
    states = useRef(new Map<string, EditorState>()),
    undos = useRef(new WeakMap<Y.Text, Y.UndoManager>());
  callbacks.current = { onChange, onRun, onBreakpoint, onLimit, onSelection };
  const options = () => [
    EditorState.readOnly.of(readOnly),
    EditorView.editable.of(!readOnly),
    EditorView.theme({ "&": { fontSize: fontSize + "px" } }),
    ...(wrap ? [EditorView.lineWrapping] : []),
  ];
  const debugOptions = () =>
    path.endsWith(".go")
      ? [
          gutter({
            class: "cm-debug-gutter",
            renderEmptyElements: true,
            lineMarker: (editor, line) => {
              const n = editor.state.doc.lineAt(line.from).number;
              return new Breakpoint(n, breakpoints.includes(n), () =>
                callbacks.current.onBreakpoint?.(n),
              );
            },
          }),
          EditorView.decorations.of((editor) =>
            debugLine && debugLine <= editor.state.doc.lines
              ? Decoration.set([
                  Decoration.line({ class: "cm-debug-current-line" }).range(
                    editor.state.doc.line(debugLine).from,
                  ),
                ])
              : Decoration.none,
          ),
        ]
      : [];
  const peerOptions = () =>
    EditorView.decorations.of((editor) => {
      const marks = peerCursors
        .filter((peer) => peer.path === path)
        .map((peer) =>
          Decoration.widget({
            widget: new PeerCaret(peer.name, peer.color),
            side: 1,
          }).range(Math.min(editor.state.doc.length, Math.max(0, peer.head))),
        );
      return Decoration.set(marks, true);
    });
  useEffect(() => {
    if (!host.current) return;
    const id = documentKey + "|" + path;
    let undo = text ? undos.current.get(text) : undefined;
    if (text && !undo) {
      undo = new Y.UndoManager(text);
      undos.current.set(text, undo);
    }
    const extensions = [
      lineNumbers(),
      highlightActiveLineGutter(),
      foldGutter(),
      drawSelection(),
      indentOnInput(),
      bracketMatching(),
      closeBrackets(),
      highlightActiveLine(),
      highlightSelectionMatches(),
      syntaxHighlighting(
        HighlightStyle.define([
          { tag: tags.keyword, color: "#d6adf4" },
          { tag: [tags.string, tags.regexp], color: "#b8cf8d" },
          { tag: [tags.number, tags.bool, tags.null], color: "#edba7c" },
          { tag: [tags.typeName, tags.className], color: "#89d0da" },
          { tag: tags.comment, color: "#91a2ad", fontStyle: "italic" },
          {
            tag: [
              tags.function(tags.variableName),
              tags.definition(tags.variableName),
            ],
            color: "#91c8f0",
          },
        ]),
      ),
      ...(path.endsWith(".go") ? [StreamLanguage.define(go)] : []),
      ...(text && awareness
        ? [yCollab(text, awareness, { undoManager: undo! })]
        : [history()]),
      keymap.of([
        {
          key: "Mod-Enter",
          run: () => {
            callbacks.current.onRun();
            return true;
          },
        },
        ...closeBracketsKeymap,
        ...(text
          ? yUndoManagerKeymap.map((binding) => ({
              ...binding,
              run: binding.run
                ? (editor: EditorView) =>
                    editor.state.readOnly ? false : binding.run!(editor)
                : undefined,
            }))
          : historyKeymap),
        ...defaultKeymap,
        ...searchKeymap,
        indentWithTab,
      ]),
      config.current.of(options()),
      debugConfig.current.of(debugOptions()),
      peerConfig.current.of(peerOptions()),
      EditorView.contentAttributes.of({
        "aria-label": "Source code",
        autocapitalize: "off",
        spellcheck: "false",
      }),
      EditorState.transactionFilter.of((transaction) => {
        if (
          transaction.docChanged &&
          !transaction.annotation(ySyncAnnotation)
        ) {
          const size = new TextEncoder().encode(
            transaction.newDoc.toString(),
          ).length;
          if (
            size > 128 * 1024 &&
            size >
              new TextEncoder().encode(transaction.startState.doc.toString())
                .length
          ) {
            queueMicrotask(() => callbacks.current.onLimit?.());
            return [];
          }
        }
        return transaction;
      }),
      EditorView.updateListener.of((update) => {
        if (update.selectionSet || update.docChanged) {
          const selection = update.state.selection.main;
          callbacks.current.onSelection?.(selection.anchor, selection.head);
        }
        if (
          update.docChanged &&
          !applying.current &&
          !update.transactions.some((t) => t.annotation(ySyncAnnotation))
        )
          callbacks.current.onChange(update.state.doc.toString());
      }),
      EditorView.theme(
        {
          "&": {
            height: "100%",
            backgroundColor: "var(--gf-editor)",
            color: "var(--gf-text)",
          },
          ".cm-content": {
            fontFamily: "ui-monospace,SFMono-Regular,Consolas,monospace",
            padding: "1rem 0",
            caretColor: "var(--gf-text)",
          },
          ".cm-scroller": { overflow: "auto", lineHeight: "1.65" },
          ".cm-gutters": {
            backgroundColor: "var(--gf-editor)",
            color: "var(--gf-muted)",
            borderRight: "1px solid var(--gf-line)",
          },
          ".cm-activeLine,.cm-activeLineGutter": {
            backgroundColor: "var(--gf-raised)",
          },
          ".cm-cursor": { borderLeftColor: "var(--gf-accent)" },
          "&.cm-focused .cm-selectionBackground,.cm-selectionBackground": {
            backgroundColor: "#376170",
          },
          ".cm-searchMatch": { backgroundColor: "#715126" },
          ".cm-panels": {
            backgroundColor: "var(--gf-panel)",
            color: "var(--gf-text)",
          },
        },
        { dark: true },
      ),
    ];
    const saved = !text ? states.current.get(id) : undefined;
    const editor = new EditorView({
      parent: host.current,
      state:
        saved ??
        EditorState.create({ doc: text ? text.toString() : value, extensions }),
    });
    view.current = editor;
    editor.dom.querySelector(".cm-gutters")?.removeAttribute("aria-hidden");
    editor.dom
      .querySelector(".cm-lineNumbers")
      ?.setAttribute("aria-hidden", "true");
    return () => {
      if (!text) {
        states.current.set(id, editor.state);
        while (states.current.size > 16)
          states.current.delete(states.current.keys().next().value!);
      }
      view.current = null;
      editor.destroy();
    };
    // The document/file identity owns history; live preferences reconfigure below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path, documentKey, text, awareness]);
  useEffect(() => {
    const editor = view.current;
    if (editor && !text && editor.state.doc.toString() !== value) {
      applying.current = true;
      editor.dispatch({
        changes: { from: 0, to: editor.state.doc.length, insert: value },
      });
      applying.current = false;
    }
  }, [value, text, path, documentKey]);
  useEffect(() => {
    view.current?.dispatch({ effects: config.current.reconfigure(options()) });
  }, [readOnly, fontSize, wrap, path, documentKey, text]);
  useEffect(() => {
    view.current?.dispatch({
      effects: debugConfig.current.reconfigure(debugOptions()),
    });
  }, [breakpoints, debugLine, path]);
  useEffect(() => {
    const editor = view.current,
      lineNumber = revealLine || debugLine;
    if (!editor || !lineNumber) return;
    const line = editor.state.doc.line(
      Math.max(1, Math.min(lineNumber, editor.state.doc.lines)),
    );
    editor.dispatch({
      selection: { anchor: line.from },
      effects: EditorView.scrollIntoView(line.from, { y: "center" }),
    });
    if (!debugLine) editor.focus();
  }, [revealLine, debugLine, path]);
  useEffect(() => {
    view.current?.dispatch({
      effects: peerConfig.current.reconfigure(peerOptions()),
    });
  }, [peerCursors, path, documentKey]);
  useEffect(() => {
    if (searchRequest && view.current) openSearchPanel(view.current);
  }, [searchRequest]);
  return <div className="gf-code-editor" ref={host} />;
}
