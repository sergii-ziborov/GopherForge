package main

// Source-level probes are injected only into a temporary debug snapshot. No
// original source is rewritten, and ordinary builds never include this code.
import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type debugPoint struct {
	ID       int    `json:"id"`
	File     string `json:"file"`
	Line     int    `json:"line"`
	Function string `json:"function"`
	Kind     int    `json:"kind"`
}
type debugOutput struct {
	Files  map[string]string `json:"files"`
	Points []debugPoint      `json:"points"`
}
type debugJob struct {
	Files  []string `json:"files"`
	Output string   `json:"output"`
}
type debugEdit struct {
	at   int
	text string
}
type debugInstrumenter struct {
	set    *token.FileSet
	file   string
	edits  []debugEdit
	output *debugOutput
}
type debugScope map[string]bool

func instrumentDebug(path string) {
	raw, err := os.ReadFile(path)
	if err != nil {
		fail(err)
	}
	var job debugJob
	if err = json.Unmarshal(raw, &job); err != nil {
		fail(err)
	}
	if !relative(job.Output) || len(job.Files) > 2000 {
		fail(fmt.Errorf("invalid debug job"))
	}
	sort.Strings(job.Files)
	output := debugOutput{Files: map[string]string{}}
	helpers := map[string]string{}
	for _, name := range job.Files {
		if !relative(name) || !strings.HasSuffix(name, ".go") || strings.HasPrefix(name, "vendor/") {
			fail(fmt.Errorf("invalid debug source path"))
		}
		raw, err := os.ReadFile(filepath.Join("/work", name))
		if err != nil {
			fail(err)
		}
		set := token.NewFileSet()
		file, err := parser.ParseFile(set, name, raw, parser.ParseComments)
		if err != nil {
			fail(err)
		}
		ast.Inspect(file, func(n ast.Node) bool {
			if id, ok := n.(*ast.Ident); ok && strings.HasPrefix(id.Name, "gopherforgeDebug") {
				fail(fmt.Errorf("%s uses the reserved gopherforgeDebug prefix", name))
			}
			return true
		})
		in := debugInstrumenter{set: set, file: name, output: &output}
		for _, decl := range file.Decls {
			if f, ok := decl.(*ast.FuncDecl); ok && f.Body != nil {
				scope := debugScope{}
				addFields(scope, f.Recv)
				addFields(scope, f.Type.Params)
				addFields(scope, f.Type.Results)
				in.function(f.Body, scope, f.Name.Name)
			}
		}
		sort.SliceStable(in.edits, func(i, j int) bool { return in.edits[i].at < in.edits[j].at })
		var changed strings.Builder
		offset := 0
		for _, edit := range in.edits {
			changed.Write(raw[offset:edit.at])
			changed.WriteString(edit.text)
			offset = edit.at
		}
		changed.Write(raw[offset:])
		output.Files[name] = changed.String()
		directory := filepath.Dir(name)
		helpers[directory] = file.Name.Name
	}
	for directory, pkg := range helpers {
		sum := sha256.Sum256([]byte(directory))
		name := filepath.Join(directory, fmt.Sprintf("zz_gopherforge_debug_%x.go", sum[:4]))
		if _, err := os.Stat(filepath.Join("/work", name)); err == nil {
			fail(fmt.Errorf("reserved debug helper already exists"))
		}
		output.Files[name] = "package " + pkg + "\n" + debugHelper
	}
	encoded, err := json.Marshal(output)
	if err != nil {
		fail(err)
	}
	if len(encoded) > 32*1024*1024 {
		fail(fmt.Errorf("instrumented source exceeds 32 MiB"))
	}
	if err = os.WriteFile(filepath.Join("/work", job.Output), encoded, 0600); err != nil {
		fail(err)
	}
	fmt.Println("Prepared temporary Go source debugger probes")
}
func copyScope(s debugScope) debugScope {
	r := debugScope{}
	for n := range s {
		r[n] = true
	}
	return r
}
func addName(s debugScope, id *ast.Ident) {
	if id != nil && id.Name != "_" {
		s[id.Name] = true
	}
}
func addFields(s debugScope, list *ast.FieldList) {
	if list != nil {
		for _, f := range list.List {
			for _, n := range f.Names {
				addName(s, n)
			}
		}
	}
}
func declared(s debugScope, node ast.Stmt) {
	switch n := node.(type) {
	case *ast.AssignStmt:
		if n.Tok == token.DEFINE {
			for _, e := range n.Lhs {
				if id, ok := e.(*ast.Ident); ok {
					addName(s, id)
				}
			}
		}
	case *ast.DeclStmt:
		if d, ok := n.Decl.(*ast.GenDecl); ok && d.Tok == token.VAR {
			for _, spec := range d.Specs {
				if v, ok := spec.(*ast.ValueSpec); ok {
					for _, id := range v.Names {
						addName(s, id)
					}
				}
			}
		}
	}
}
func (in *debugInstrumenter) point(pos token.Pos, function string, kind int) int {
	if len(in.output.Points) >= 20000 {
		fail(fmt.Errorf("debugger exceeds 20,000 source probes"))
	}
	id := len(in.output.Points) + 1
	in.output.Points = append(in.output.Points, debugPoint{id, in.file, in.set.Position(pos).Line, function, kind})
	return id
}
func (in *debugInstrumenter) insert(pos token.Pos, text string) {
	in.edits = append(in.edits, debugEdit{in.set.Position(pos).Offset, text})
}
func (in *debugInstrumenter) probe(pos token.Pos, scope debugScope, function string) {
	id := in.point(pos, function, 0)
	names := []string{}
	for name := range scope {
		names = append(names, name)
	}
	sort.Strings(names)
	if len(names) > 48 {
		names = names[:48]
	}
	keys := []string{}
	for _, n := range names {
		keys = append(keys, fmt.Sprintf("%q", n))
	}
	in.insert(pos, fmt.Sprintf("gopherforgeDebugCheckpoint(0,%d,[]string{%s},[]any{%s});", id, strings.Join(keys, ","), strings.Join(names, ",")))
}
func (in *debugInstrumenter) function(body *ast.BlockStmt, scope debugScope, name string) {
	id := in.point(body.Lbrace, name, 1)
	in.insert(body.Lbrace+1, fmt.Sprintf("gopherforgeDebugCheckpoint(1,%d,nil,nil);defer gopherforgeDebugCheckpoint(2,%d,nil,nil);", id, id))
	in.block(body, scope, name)
}
func (in *debugInstrumenter) expressions(node ast.Node, scope debugScope, name string) {
	if node == nil {
		return
	}
	ast.Inspect(node, func(n ast.Node) bool {
		if f, ok := n.(*ast.FuncLit); ok {
			s := copyScope(scope)
			addFields(s, f.Type.Params)
			addFields(s, f.Type.Results)
			in.function(f.Body, s, fmt.Sprintf("%s.func@%d", name, in.set.Position(f.Pos()).Line))
			return false
		}
		if _, ok := n.(*ast.BlockStmt); ok {
			return false
		}
		return true
	})
}
func (in *debugInstrumenter) block(body *ast.BlockStmt, scope debugScope, name string) {
	in.statements(body.List, copyScope(scope), name)
}
func (in *debugInstrumenter) statements(list []ast.Stmt, scope debugScope, name string) {
	for _, stmt := range list {
		compileOnly := false
		if declaration, ok := stmt.(*ast.DeclStmt); ok {
			if group, ok := declaration.Decl.(*ast.GenDecl); ok {
				compileOnly = group.Tok != token.VAR
			}
		}
		if _, label := stmt.(*ast.LabeledStmt); !label && !compileOnly {
			if _, empty := stmt.(*ast.EmptyStmt); !empty {
				in.probe(stmt.Pos(), scope, name)
			}
		}
		in.statement(stmt, scope, name)
		declared(scope, stmt)
	}
}
func (in *debugInstrumenter) statement(stmt ast.Stmt, scope debugScope, name string) {
	switch s := stmt.(type) {
	case *ast.BlockStmt:
		in.block(s, scope, name)
	case *ast.IfStmt:
		local := copyScope(scope)
		in.expressions(s.Init, local, name)
		if s.Init != nil {
			declared(local, s.Init)
		}
		in.expressions(s.Cond, local, name)
		in.block(s.Body, local, name)
		if s.Else != nil {
			in.statement(s.Else, local, name)
		}
	case *ast.ForStmt:
		local := copyScope(scope)
		in.expressions(s.Init, local, name)
		if s.Init != nil {
			declared(local, s.Init)
		}
		in.expressions(s.Cond, local, name)
		in.expressions(s.Post, local, name)
		in.probe(s.Body.Lbrace+1, local, name)
		in.block(s.Body, local, name)
	case *ast.RangeStmt:
		local := copyScope(scope)
		in.expressions(s.X, scope, name)
		if s.Tok == token.DEFINE {
			if id, ok := s.Key.(*ast.Ident); ok {
				addName(local, id)
			}
			if id, ok := s.Value.(*ast.Ident); ok {
				addName(local, id)
			}
		}
		in.probe(s.Body.Lbrace+1, local, name)
		in.block(s.Body, local, name)
	case *ast.SwitchStmt:
		local := copyScope(scope)
		in.expressions(s.Init, local, name)
		if s.Init != nil {
			declared(local, s.Init)
		}
		in.expressions(s.Tag, local, name)
		for _, item := range s.Body.List {
			c := item.(*ast.CaseClause)
			for _, e := range c.List {
				in.expressions(e, local, name)
			}
			in.statements(c.Body, copyScope(local), name)
		}
	case *ast.TypeSwitchStmt:
		local := copyScope(scope)
		if s.Init != nil {
			in.expressions(s.Init, local, name)
			declared(local, s.Init)
		}
		declared(local, s.Assign)
		for _, item := range s.Body.List {
			in.statements(item.(*ast.CaseClause).Body, copyScope(local), name)
		}
	case *ast.SelectStmt:
		for _, item := range s.Body.List {
			c := item.(*ast.CommClause)
			local := copyScope(scope)
			if c.Comm != nil {
				in.expressions(c.Comm, local, name)
				declared(local, c.Comm)
			}
			in.statements(c.Body, local, name)
		}
	case *ast.LabeledStmt:
		in.statement(s.Stmt, scope, name)
	default:
		in.expressions(stmt, scope, name)
	}
}

const debugHelper = `
import (
 "encoding/json"
 "reflect"
 "runtime"
 "strconv"
 "strings"
 "unsafe"
)
//go:wasmimport gopherforge_debug checkpoint
func gopherforgeDebugHost(kind, id, goroutine, pointer, length uint32)
func gopherforgeDebugCheckpoint(kind, id uint32, names []string, values []any) {
 var stack [64]byte
 n:=runtime.Stack(stack[:],false)
 var gid uint32
 for i:=10;i<n&&stack[i]>='0'&&stack[i]<='9';i++{gid=gid*10+uint32(stack[i]-'0')}
 snapshot:=map[string]string{}
 for i,name:=range names{if i>=len(values)||i>=48{break};snapshot[name]=gopherforgeDebugValue(reflect.ValueOf(values[i]),0)}
 payload,_:=json.Marshal(snapshot)
 if len(payload)>65536{payload=[]byte("{}")}
 var pointer uint32
 if len(payload)>0{pointer=uint32(uintptr(unsafe.Pointer(&payload[0])))}
 gopherforgeDebugHost(kind,id,gid,pointer,uint32(len(payload)))
 runtime.KeepAlive(payload)
}
func gopherforgeDebugValue(v reflect.Value,depth int)(result string){
 defer func(){if recover()!=nil{result="<unavailable>"}}()
 if !v.IsValid(){return "nil"}
 if depth>2{return v.Type().String()}
 switch v.Kind(){
 case reflect.Bool:return strconv.FormatBool(v.Bool())
 case reflect.Int,reflect.Int8,reflect.Int16,reflect.Int32,reflect.Int64:return strconv.FormatInt(v.Int(),10)
 case reflect.Uint,reflect.Uint8,reflect.Uint16,reflect.Uint32,reflect.Uint64,reflect.Uintptr:return strconv.FormatUint(v.Uint(),10)
 case reflect.Float32,reflect.Float64:return strconv.FormatFloat(v.Float(),'g',-1,64)
 case reflect.String:s:=v.String();if len(s)>256{s=s[:256]+"…"};return strconv.Quote(s)
 case reflect.Interface,reflect.Pointer:if v.IsNil(){return v.Type().String()+"(nil)"};return gopherforgeDebugValue(v.Elem(),depth+1)
 case reflect.Slice:if v.IsNil(){return v.Type().String()+"(nil)"};return v.Type().String()+" len="+strconv.Itoa(v.Len())+" cap="+strconv.Itoa(v.Cap())
 case reflect.Array,reflect.Map:return v.Type().String()+" len="+strconv.Itoa(v.Len())
 case reflect.Chan:return v.Type().String()+" len="+strconv.Itoa(v.Len())+" cap="+strconv.Itoa(v.Cap())
 case reflect.Struct:parts:=[]string{};for i:=0;i<v.NumField()&&i<8;i++{parts=append(parts,v.Type().Field(i).Name+":"+gopherforgeDebugValue(v.Field(i),depth+1))};s:=v.Type().String()+"{"+strings.Join(parts,", ")+"}";if len(s)>512{s=s[:512]+"…"};return s
 default:return v.Type().String()
 }
}
`
