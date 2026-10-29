#!/usr/bin/env python3
"""Compile and exercise the actual twelve Go algorithm examples in the shared bank."""
import json,pathlib,subprocess,tempfile,os
root=pathlib.Path(__file__).resolve().parents[1]
bank=json.loads((root/'GopherForge/Resources/InterviewPrep.json').read_text())
demonstrated={d['id'] for d in bank['demonstrations']}
examples=[q['code'] for q in bank['questions'] if q['id'] in demonstrated]
assert len(examples)==12 and all(examples)
source='package algorithms\nimport("container/heap";"container/list";"sort")\n'+'\n'.join(examples)
tests=r'''package algorithms
import("testing";"reflect";"math/rand";"sort")
func TestTraceScenarios(t *testing.T) {
 if LowerBound([]int{1,3,3,8},3)!=1 || LowerBound(nil,5)!=0 || LowerBound([]int{2,4,6},9)!=3 { t.Fatal("boundary") }
 for _, c:=range []struct{xs []int; target int; ok bool}{{[]int{2,7,11,15},9,true},{[]int{3,3},6,true},{[]int{1,2,3},10,false}} {
  i,j,ok:=TwoSum(c.xs,c.target);if ok!=c.ok || ok&&(i==j||c.xs[i]+c.xs[j]!=c.target){t.Fatal(c)}
 }
 for s,want:=range map[string]int{"abba":2,"abcabcbb":3,"aaaa":1,"":0}{if got:=UniqueBytes(s);got!=want{t.Fatal(s,got)}}
 if got:=Distances([][]int{{1,2},{3},{3,4},nil,nil},0);!reflect.DeepEqual(got,[]int{0,1,1,2,2}){t.Fatal(got)}
 if got:=Distances([][]int{{1},nil,{3},nil},0);!reflect.DeepEqual(got,[]int{0,1,-1,-1}){t.Fatal(got)}
 if got:=ShortestDistances([][]Edge{{{1,4},{2,1}},nil,{{1,2}}},0);!reflect.DeepEqual(got,[]int{0,3,1}){t.Fatal(got)}
 if got:=ShortestDistances([][]Edge{{{1,0},{2,5}},{{2,1}},nil},0);!reflect.DeepEqual(got,[]int{0,0,1}){t.Fatal(got)}
 if got:=ShortestDistances([][]Edge{{{1,2}},nil,nil},0);!reflect.DeepEqual(got,[]int{0,2,-1}){t.Fatal(got)}
 if got:=TopK([]int{5,1,9,3,8},3);!reflect.DeepEqual(got,[]int{5,8,9}){t.Fatal(got)}
 if got:=TopK([]int{4,4,2,4},2);!reflect.DeepEqual(got,[]int{4,4}){t.Fatal(got)}
 if got:=Merge([]int{1,4,8},[]int{2,4,7});!reflect.DeepEqual(got,[]int{1,2,4,4,7,8}){t.Fatal(got)}
 if MinCoins([]int{1,3,4},6)!=2||MinCoins([]int{2,4},3)!=-1||MinCoins([]int{2,5},0)!=0{t.Fatal("dp")}
}
func TestRandomizedReferenceComparisons(t *testing.T) {
 rng:=rand.New(rand.NewSource(39))
 for round:=0;round<500;round++ {
  n:=rng.Intn(40);xs:=make([]int,n);for i:=range xs{xs[i]=rng.Intn(31)-15}
  sorted:=append([]int(nil),xs...);sort.Ints(sorted)
  target:=rng.Intn(41)-20;want:=0;for want<n&&sorted[want]<target{want++};if LowerBound(sorted,target)!=want{t.Fatal("search")}
  k:=rng.Intn(45);got:=TopK(xs,k);start:=n-k;if start<0{start=0};expected:=sorted[start:];if len(got)!=len(expected){t.Fatal("topK length")};for i:=range got{if got[i]!=expected[i]{t.Fatal("topK")}}
  split:=n/2;if got:=Merge(sorted[:split],sorted[split:]);!reflect.DeepEqual(got,sorted)&&len(sorted)>0{t.Fatal("merge")}
  found:=false;for i:=range xs{for j:=i+1;j<n;j++{if xs[i]+xs[j]==target{found=true}}};i,j,ok:=TwoSum(xs,target);if ok!=found||ok&&(i==j||xs[i]+xs[j]!=target){t.Fatal("two sum")}
 }
}
func validOrder(adj [][]int, order []int) bool {
 if len(order)!=len(adj){return false};pos:=make([]int,len(adj));seen:=make([]bool,len(adj))
 for i,v:=range order{if v<0||v>=len(adj)||seen[v]{return false};seen[v]=true;pos[v]=i}
 for u,edges:=range adj{for _,v:=range edges{if pos[u]>=pos[v]{return false}}};return true
}
func TestExpandedTraceScenarios(t *testing.T) {
 dag:=[][]int{{1,2},{3},{3},nil};order,ok:=TopologicalOrder(dag)
 if !ok||!validOrder(dag,order){t.Fatal("DAG",order)}
 if _,ok:=TopologicalOrder([][]int{{1},{0}});ok{t.Fatal("cycle")}
 if order,ok:=TopologicalOrder(nil);!ok||len(order)!=0{t.Fatal("empty")}
 d:=NewDisjointSet(5);d.Union(0,1);d.Union(1,2);d.Union(3,4)
 if d.Components!=2||d.Find(0)!=d.Find(2)||d.Find(0)==d.Find(4){t.Fatal("connectivity")}
 d=NewDisjointSet(3);d.Union(0,1);if d.Union(0,1)||d.Components!=2{t.Fatal("redundant")}
 if NewDisjointSet(0).Components!=0{t.Fatal("empty DSU")}
 c:=NewLRU(2);c.Put(1,10);c.Put(2,20);c.Get(1);c.Put(3,30)
 if _,ok:=c.Get(2);ok{t.Fatal("eviction")};if v,ok:=c.Get(1);!ok||v!=10{t.Fatal("hit")}
 c=NewLRU(2);c.Put(1,10);c.Put(1,99);if v,ok:=c.Get(1);!ok||v!=99||c.order.Len()!=1{t.Fatal("update")}
 c=NewLRU(0);c.Put(1,10);if _,ok:=c.Get(1);ok{t.Fatal("zero capacity")}
 input:=[]Interval{{1,4},{2,3},{4,6},{9,10}};original:=append([]Interval(nil),input...)
 if got:=MergeIntervals(input);!reflect.DeepEqual(got,[]Interval{{1,6},{9,10}}){t.Fatal(got)}
 if !reflect.DeepEqual(input,original){t.Fatal("mutated caller input")}
 if got:=MergeIntervals([]Interval{{5,6},{1,2}});!reflect.DeepEqual(got,[]Interval{{1,2},{5,6}}){t.Fatal(got)}
 if len(MergeIntervals(nil))!=0{t.Fatal("empty intervals")}
}
func TestExpandedRandomizedProperties(t *testing.T) {
 rng:=rand.New(rand.NewSource(45))
 for round:=0;round<200;round++ {
  n:=rng.Intn(16);adj:=make([][]int,n)
  for u:=range adj{for v:=u+1;v<n;v++{if rng.Intn(5)==0{adj[u]=append(adj[u],v)}}}
  if order,ok:=TopologicalOrder(adj);!ok||!validOrder(adj,order){t.Fatal("topology")}
  ds:=NewDisjointSet(n);graph:=make([][]int,n)
  for k:=0;k<30&&n>0;k++ {
   a,b:=rng.Intn(n),rng.Intn(n);ds.Union(a,b);graph[a]=append(graph[a],b);graph[b]=append(graph[b],a)
   seen:=make([]bool,n);components:=0
   var visit func(int);visit=func(u int){if seen[u]{return};seen[u]=true;for _,v:=range graph[u]{visit(v)}}
   for u:=range graph{if !seen[u]{components++;visit(u)}}
   if ds.Components!=components{t.Fatal("DSU components")}
  }
  capacity:=rng.Intn(5);cache:=NewLRU(capacity);values:=map[int]int{};recent:=[]int{}
  touch:=func(key int){next:=[]int{key};for _,k:=range recent{if k!=key{next=append(next,k)}};recent=next}
  for k:=0;k<100;k++ {
   key:=rng.Intn(8)
   if rng.Intn(2)==0 {
    value:=rng.Intn(100);cache.Put(key,value)
    if capacity>0{values[key]=value;touch(key);if len(recent)>capacity{delete(values,recent[len(recent)-1]);recent=recent[:capacity]}}
   } else {
    want,found:=values[key];got,ok:=cache.Get(key);if found!=ok||found&&got!=want{t.Fatal("LRU result")};if found{touch(key)}
   }
   if len(cache.entries)!=len(values)||cache.order.Len()!=len(recent){t.Fatal("LRU structure")}
   index:=0;for e:=cache.order.Front();e!=nil;e=e.Next(){if e.Value.(lruEntry).key!=recent[index]{t.Fatal("LRU recency")};index++}
  }
  intervals:=make([]Interval,rng.Intn(20));for i:=range intervals{a,b:=rng.Intn(21)-10,rng.Intn(21)-10;if a>b{a,b=b,a};intervals[i]=Interval{a,b}}
  merged:=MergeIntervals(intervals)
  for i,x:=range merged{if x.Start>x.End||i>0&&merged[i-1].End>=x.Start{t.Fatal("non-disjoint output")}}
  for point:=-10;point<=10;point++ {before,after:=false,false;for _,x:=range intervals{before=before||x.Start<=point&&point<=x.End};for _,x:=range merged{after=after||x.Start<=point&&point<=x.End};if before!=after{t.Fatal("coverage")}}
 }
}
'''
with tempfile.TemporaryDirectory(prefix='gopherforge-interview-') as folder:
 p=pathlib.Path(folder);(p/'go.mod').write_text('module interviewexamples\ngo 1.24\n');(p/'algorithms.go').write_text(source);(p/'algorithms_test.go').write_text(tests)
 env=dict(os.environ,GOWORK='off',GOTOOLCHAIN='local',GOMAXPROCS='2')
 subprocess.run(['go','test','-race','-count=1','./...'],cwd=p,env=env,check=True)
print('12 published Go examples compiled; original boundaries/500 randomized rounds and new trace scenarios/200 property rounds passed with race detector.')
