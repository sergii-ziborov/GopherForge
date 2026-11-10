package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

type request struct {
	Source string `json:"source"`
	State  State  `json:"state"`
}

func main() {
	// These are fixed control files in the sole WASI preopen. They are never
	// interpreted as user paths; the shell's filesystem is only the State map.
	f, e := os.Open("/control/request.json")
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(2)
	}
	var req request
	d := json.NewDecoder(io.LimitReader(f, 16*1024*1024))
	e = d.Decode(&req)
	f.Close()
	if e != nil {
		fmt.Fprintln(os.Stderr, "invalid lab request")
		os.Exit(2)
	}
	result := run(req.Source, req.State, func() bool { return checkpoint() != 0 })
	data, e := json.Marshal(result)
	if e != nil {
		os.Exit(2)
	}
	if e = os.WriteFile("/control/response.json", data, 0600); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(2)
	}
}
