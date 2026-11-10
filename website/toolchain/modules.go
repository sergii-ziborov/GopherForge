package main

import (
	"bytes"
	"encoding/base64"
	"errors"
	"fmt"
	"golang.org/x/mod/modfile"
	"golang.org/x/mod/module"
	"golang.org/x/mod/sumdb"
	"os"
	"sort"
	"strings"
	"sync"
)

type moduleRequirement struct {
	Path    string `json:"path"`
	Version string `json:"version"`
}
type moduleSpec struct {
	Module     string              `json:"module"`
	Go         string              `json:"go"`
	Requires   []moduleRequirement `json:"requires"`
	Excludes   []moduleRequirement `json:"excludes"`
	HasReplace bool                `json:"hasReplace"`
}

func parseModule(text string) *moduleSpec {
	f, err := modfile.Parse("go.mod", []byte(text), nil)
	if err != nil {
		fail("%s", err)
	}
	result := &moduleSpec{Requires: []moduleRequirement{}, Excludes: []moduleRequirement{}, HasReplace: len(f.Replace) > 0}
	if f.Module != nil {
		result.Module = f.Module.Mod.Path
	}
	if f.Go != nil {
		result.Go = f.Go.Version
	}
	for _, r := range f.Require {
		result.Requires = append(result.Requires, moduleRequirement{r.Mod.Path, r.Mod.Version})
	}
	for _, r := range f.Exclude {
		result.Excludes = append(result.Excludes, moduleRequirement{r.Mod.Path, r.Mod.Version})
	}
	return result
}

const sumdbVerifier = "sum.golang.org+033de0ae+Ac4zctda0e5eza+HJyk9SxEdh+s3Ux18htTTAD8OuAn8"

type checksumOps struct {
	mu       sync.Mutex
	remote   map[string]string
	latest   []byte
	cache    map[string][]byte
	need     map[string]bool
	security string
}

func (o *checksumOps) ReadRemote(path string) ([]byte, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if data, ok := o.remote[path]; ok {
		if strings.HasPrefix(data, "HTTP ") {
			return nil, errors.New(data)
		}
		return base64.StdEncoding.DecodeString(data)
	}
	o.need[path] = true
	return nil, fmt.Errorf("remote data needed")
}
func (o *checksumOps) ReadConfig(name string) ([]byte, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if name == "key" {
		return []byte(sumdbVerifier), nil
	}
	if name == "sum.golang.org/latest" {
		return append([]byte{}, o.latest...), nil
	}
	return nil, os.ErrNotExist
}
func (o *checksumOps) WriteConfig(name string, old, next []byte) error {
	o.mu.Lock()
	defer o.mu.Unlock()
	if name != "sum.golang.org/latest" || !bytes.Equal(o.latest, old) {
		return sumdb.ErrWriteConflict
	}
	o.latest = append([]byte{}, next...)
	return nil
}
func (o *checksumOps) ReadCache(name string) ([]byte, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if v, ok := o.cache[name]; ok {
		return v, nil
	}
	return nil, os.ErrNotExist
}
func (o *checksumOps) WriteCache(name string, data []byte) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.cache[name] = append([]byte{}, data...)
}
func (o *checksumOps) Log(msg string)           {}
func (o *checksumOps) SecurityError(msg string) { o.mu.Lock(); defer o.mu.Unlock(); o.security = msg }
func verifyChecksum() {
	if module.CheckPath(input.Module) != nil || module.CanonicalVersion(input.Version) != input.Version {
		fail("Use a valid module path and exact canonical version")
	}
	if len(input.Remote) > 96 {
		fail("Checksum proof exceeds its request budget")
	}
	total := 0
	for path, data := range input.Remote {
		total += len(data)
		if (!strings.HasPrefix(path, "/lookup/") && !strings.HasPrefix(path, "/tile/")) || strings.Contains(path, "..") {
			fail("Invalid checksum proof path")
		}
	}
	if total > 4*1024*1024 {
		fail("Checksum proof exceeds 4 MiB")
	}
	ops := &checksumOps{remote: input.Remote, latest: []byte(input.Latest), cache: map[string][]byte{}, need: map[string]bool{}}
	client := sumdb.NewClient(ops)
	lines, err := client.Lookup(input.Module, input.Version)
	if err == nil {
		var mod []string
		mod, err = client.Lookup(input.Module, input.Version+"/go.mod")
		lines = append(lines, mod...)
	}
	if ops.security != "" || errors.Is(err, sumdb.ErrSecurity) {
		fail("Checksum database verification failed: %s", ops.security)
	}
	if len(ops.need) > 0 {
		for path := range ops.need {
			plan.Need = append(plan.Need, path)
		}
		sort.Strings(plan.Need)
		return
	}
	if err != nil {
		fail("Checksum verification: %s", err)
	}
	plan.Verified = lines
	plan.Latest = string(ops.latest)
}
