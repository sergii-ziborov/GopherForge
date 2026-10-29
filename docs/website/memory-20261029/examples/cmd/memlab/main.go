package main

import (
	"encoding/json"
	"flag"
	"fmt"
	lab "gopherforge.news/memorylab"
	"os"
	"runtime"
	"runtime/debug"
	"runtime/metrics"
	"runtime/pprof"
	"sort"
	"time"
)

var ephemeral []byte

//go:noinline
func churnBlock(n int) []byte { return make([]byte, n) }

//go:noinline
func retainedBlock(n int) []byte { return make([]byte, n) }
func metric(name string) uint64 {
	samples := []metrics.Sample{{Name: name}}
	metrics.Read(samples)
	if samples[0].Value.Kind() != metrics.KindUint64 {
		panic("unexpected metric: " + name)
	}
	return samples[0].Value.Uint64()
}
func main() {
	mode := flag.String("mode", "gc", "gc, chain, tree, view, clip, copy, profile")
	out := flag.String("out", "heap.pprof", "profile output file")
	flag.Parse()
	runtime.GOMAXPROCS(2)
	var before, after runtime.MemStats
	report := map[string]any{"go": runtime.Version(), "os": runtime.GOOS, "arch": runtime.GOARCH, "gomaxprocs": runtime.GOMAXPROCS(0), "mode": *mode, "gogc": os.Getenv("GOGC"), "gomemlimit": os.Getenv("GOMEMLIMIT")}
	runtime.GC()
	runtime.ReadMemStats(&before)
	scanBefore := metric("/gc/scan/heap:bytes")
	baselineHeap := before.HeapAlloc
	var root any
	switch *mode {
	case "gc":
		root = retainedBlock(12 << 20)
		runtime.GC()
		runtime.ReadMemStats(&before)
		start := time.Now()
		for range 512 {
			ephemeral = churnBlock(512 << 10)
		}
		elapsed := time.Since(start)
		runtime.ReadMemStats(&after)
		report["allocation_loop_ms"] = float64(elapsed) / float64(time.Millisecond)
		report["allocated_bytes"] = after.TotalAlloc - before.TotalAlloc
		report["collections_during_loop"] = after.NumGC - before.NumGC
		report["heap_at_loop_end_bytes"] = after.HeapAlloc
		report["heap_goal_bytes"] = metric("/gc/heap/goal:bytes")
		report["gc_percent"] = metric("/gc/gogc:percent")
		report["memory_limit_bytes"] = debug.SetMemoryLimit(-1)
		ephemeral = nil
		runtime.GC()
	case "chain", "tree":
		graph := lab.BuildGraph(100000, *mode)
		count, depth := lab.GraphStats(graph)
		root = graph
		report["nodes"], report["graph_depth"] = count, depth
		runtime.GC() // Discard the construction index and validation work.
		rounds := make([]float64, 7)
		for i := range rounds {
			start := time.Now()
			runtime.GC()
			rounds[i] = float64(time.Since(start)) / float64(time.Millisecond)
		}
		sort.Float64s(rounds)
		report["forced_gc_ms_sorted"] = rounds
		report["forced_gc_ms_median"] = rounds[len(rounds)/2]
	case "view", "clip", "copy":
		token := lab.RetainToken(*mode)
		root = token
		report["token_len"], report["token_cap"] = len(token), cap(token)
		runtime.GC()
	case "profile":
		runtime.MemProfileRate = 64 << 10
		kept := make([][]byte, 0, 16)
		for i := range 2048 {
			if i%128 == 0 {
				kept = append(kept, retainedBlock(64<<10))
			} else {
				ephemeral = churnBlock(64 << 10)
			}
		}
		ephemeral = nil
		root = kept
		runtime.GC()
		runtime.GC()
		f, err := os.Create(*out)
		if err != nil {
			panic(err)
		}
		if err = pprof.WriteHeapProfile(f); err != nil {
			panic(err)
		}
		if err = f.Close(); err != nil {
			panic(err)
		}
		report["profile_rate_bytes"] = runtime.MemProfileRate
		report["retained_blocks"] = len(kept)
		report["expected_payload_bytes"] = len(kept) * (64 << 10)
		report["profile_file"] = *out
	default:
		fmt.Fprintln(os.Stderr, "unknown mode")
		os.Exit(2)
	}
	runtime.ReadMemStats(&after)
	report["live_heap_after_gc_bytes"] = after.HeapAlloc
	report["heap_after_gc_delta_bytes"] = int64(after.HeapAlloc) - int64(baselineHeap)
	report["scan_heap_delta_bytes"] = int64(metric("/gc/scan/heap:bytes")) - int64(scanBefore)
	report["runtime_managed_bytes"] = after.Sys - after.HeapReleased
	report["sys_bytes"], report["heap_released_bytes"] = after.Sys, after.HeapReleased
	runtime.KeepAlive(root)
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(report); err != nil {
		panic(err)
	}
}
