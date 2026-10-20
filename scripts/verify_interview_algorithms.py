#!/usr/bin/env python3
"""Compile and exercise the actual eight Go algorithm examples in the shared bank."""
import json,pathlib,subprocess,tempfile,os
root=pathlib.Path(__file__).resolve().parents[1]
bank=json.loads((root/'GopherForge/Resources/InterviewPrep.json').read_text())
examples=[q['code'] for q in bank['questions'] if q['topic']=='algorithms']
assert len(examples)==8 and all(examples)
source='package algorithms\nimport("container/heap";"sort")\n'+'\n'.join(examples)
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
'''
with tempfile.TemporaryDirectory(prefix='gopherforge-interview-') as folder:
 p=pathlib.Path(folder);(p/'go.mod').write_text('module interviewexamples\ngo 1.24\n');(p/'algorithms.go').write_text(source);(p/'algorithms_test.go').write_text(tests)
 env=dict(os.environ,GOWORK='off',GOTOOLCHAIN='local',GOMAXPROCS='2')
 subprocess.run(['go','test','-race','-count=1','./...'],cwd=p,env=env,check=True)
print('8 published Go examples compiled; boundary and 500 randomized reference comparisons passed with race detector.')
