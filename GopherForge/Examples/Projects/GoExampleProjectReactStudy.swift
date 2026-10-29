import Foundation

/// A real multi-file React/TSX frontend; its packages and compiler are bundled.
enum GoExampleProjectReactStudy {
    static let board = GoExample(
        id: "site.react-offline",
        title: "React + Gin study board",
        summary: "Build React/TypeScript offline, edit components and practice state, CSS and JSON.",
        takeaway: "In Terminal: frontend install, then frontend build. Open Output for the isolated preview. Go Run checks the Gin-compatible routes separately; preview JSON is in web/api.",
        conceptTags: [GoConcept.stdlibHTTP, GoConcept.stdlibJSON],
        source: """
        package main

        import (
        \t"net/http"
        \t"github.com/gin-gonic/gin"
        )

        func main() {
        \tr := gin.Default()
        \tr.GET("/", func(c *gin.Context) { c.String(http.StatusOK, "Build the React frontend in Terminal") })
        \tr.GET("/api/summary", func(c *gin.Context) {
        \t\tc.JSON(http.StatusOK, map[string]any{"topics": []string{"Components", "State", "Sandbox"}, "mode": "offline"})
        \t})
        \t_ = r.Run(":8080")
        }
        """,
        expectedOutput: """
        Checking Gin routes for 127.0.0.1:8080 (host preview serves files)
        GET / 200
        GET /api/summary 200

        """,
        extraFiles: GoExampleGinVendor.files(modulePath: "example.com/sites/react-study").merging([
            "package.json": """
            {"name":"offline-study-board","private":true,"scripts":{"build":"gopherforge build","preview":"gopherforge preview"},"dependencies":{"react":"19.3.1","react-dom":"19.3.1"}}
            """,
            "gopherforge.frontend.json": """
            {"entry":"web/src/main.tsx","html":"web/index.html","output":"web/dist","minify":true}
            """,
            "web/index.html": """
            <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offline study board</title></head><body><div id="root"></div><!-- gopherforge:assets --></body></html>
            """,
            "web/api/summary.json": """
            {"topics":["Components","State","Sandbox"],"mode":"offline"}
            """,
            "web/src/model.ts": """
            export type Task = { id: number; title: string; done: boolean };
            export type Action = { type: 'add'; title: string } | { type: 'toggle'; id: number };
            export const initial: Task[] = [{id:1,title:'Read the Go route',done:true},{id:2,title:'Edit a React component',done:false}];
            export function reducer(tasks: Task[], action: Action): Task[] {
              if (action.type === 'add') return [...tasks,{id:Math.max(0,...tasks.map(t=>t.id))+1,title:action.title,done:false}];
              return tasks.map(task=>task.id===action.id?{...task,done:!task.done}:task);
            }
            """,
            "web/src/TaskRow.tsx": """
            import type { Task } from './model';
            export function TaskRow({task,toggle}:{task:Task;toggle:()=>void}) {
              return <li><label><input type="checkbox" checked={task.done} onChange={toggle}/><span className={task.done?'done':''}>{task.title}</span></label></li>;
            }
            """,
            "web/src/Stats.tsx": """
            export default function Stats({done,total}:{done:number;total:number}) {
              return <aside id="stats">{done} completed / {total} tasks. State stays in this preview.</aside>;
            }
            """,
            "web/src/main.tsx": """
            import { useEffect, useReducer, useState, lazy, Suspense } from 'react';
            import { createRoot } from 'react-dom/client';
            import { reducer, initial } from './model';
            import { TaskRow } from './TaskRow';
            import './style.css';
            const Stats = lazy(()=>import('./Stats'));
            function App() {
              const [tasks,dispatch] = useReducer(reducer,initial);
              const [title,setTitle] = useState('');
              const [filter,setFilter] = useState('all');
              const [topics,setTopics] = useState<string[]>([]);
              const [error,setError] = useState('');
              useEffect(()=>{fetch('/api/summary').then(r=>r.json()).then(body=>setTopics(body.topics)).catch(()=>setError('Local JSON could not load'));},[]);
              const visible = tasks.filter(task=>filter==='all'||(filter==='done')===task.done);
              return <main><header><span className="badge">OFFLINE · REACT + GIN</span><h1>Build your<br/>understanding.</h1><p>Real TSX components. Local packages. An isolated preview.</p></header>
                <section><h2>Your next small step</h2><form onSubmit={event=>{event.preventDefault();const clean=title.trim();if(!clean||clean.length>80){setError('Enter a task between 1 and 80 characters');return;}dispatch({type:'add',title:clean});setTitle('');setError('');}}>
                  <label htmlFor="task">Task</label><div className="composer"><input id="task" value={title} onChange={e=>setTitle(e.target.value)} placeholder="What will you try?"/><button type="submit">Add task</button></div>
                </form>{error&&<p role="alert">{error}</p>}
                <nav aria-label="Filter tasks">{['all','open','done'].map(value=><button key={value} aria-pressed={filter===value} onClick={()=>setFilter(value)}>{value}</button>)}</nav>
                <ul id="tasks">{visible.map(task=><TaskRow key={task.id} task={task} toggle={()=>dispatch({type:'toggle',id:task.id})}/>)}</ul>
                <Suspense fallback={<p>Loading stats…</p>}><Stats done={tasks.filter(t=>t.done).length} total={tasks.length}/></Suspense></section>
                <footer><strong>From local JSON</strong><p id="topics">{topics.join(' · ')||'Loading…'}</p><small>Go routes are checked with httptest. This preview reads web/api/summary.json.</small></footer></main>;
            }
            createRoot(document.getElementById('root')!).render(<App/>);
            """,
            "web/src/style.css": """
            :root{color-scheme:light;--ink:#163c43;--accent:#007f8b;--paper:#f5f3eb}*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.6 system-ui,sans-serif}main{max-width:780px;padding:32px 20px;margin:auto}h1{font-size:clamp(38px,8vw,64px);line-height:1.05;letter-spacing:-.06em}h2{font-size:22px}.badge{font-size:11px;font-weight:800;letter-spacing:.18em;color:var(--accent)}section,footer{background:#fffef9;border:1px solid #ccd8d1;border-radius:20px;padding:24px;margin:24px 0}label{display:block}.composer{display:flex;gap:8px;flex-wrap:wrap}input:not([type=checkbox]){flex:1;min-width:160px;border:1px solid #bdcec9;border-radius:10px;padding:12px;font:inherit}button{border:0;border-radius:10px;background:var(--accent);color:white;padding:12px 16px;font:inherit;cursor:pointer}nav{display:flex;gap:8px;margin:20px 0}nav button{background:#e5eeeb;color:var(--ink);text-transform:capitalize}nav button[aria-pressed=true]{background:var(--accent);color:white}ul{list-style:none;padding:0}li{padding:14px 0;border-bottom:1px solid #e0e5de}li label{display:flex;align-items:center;gap:12px}input[type=checkbox]{width:20px;height:20px;accent-color:var(--accent)}.done{text-decoration:line-through;opacity:.6}aside,small{font-size:13px;color:#587277}[role=alert]{color:#a33440}footer p{color:var(--accent)}
            """,
            "README.md": """
            # Offline React + Gin study board

            Open Terminal, run `frontend packages`, `npm install --offline`, then
            `npm run build`. The app uses its own offline catalog and esbuild
            WASI compiler. These npm commands are an educational subset;
            a full Node.js/npm runtime is not bundled.

            Open Output for the isolated preview. There is no registry, cloud,
            Node server, Vite plugin execution or external network. TypeScript is
            transpiled, not type-checked. Edit main.tsx, model.ts or TaskRow.tsx,
            then rebuild. Full-screen preview is inside the same isolated viewer.

            Go Run independently checks the bundled Gin-compatible route subset
            through httptest. Preview JSON comes from web/api/summary.json; it is
            not a live arbitrary Go HTTP server. Study request/response contracts
            without giving the guest sockets.
            """
        ], uniquingKeysWith: { _, incoming in incoming })
    )
}
