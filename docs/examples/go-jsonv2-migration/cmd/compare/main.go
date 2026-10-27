package main

import (
	jsonv1 "encoding/json"
	jsonv2 "encoding/json/v2"
	"fmt"

	migration "example.com/jsonv2migration"
)

// must is only for this small comparison program.
func must(b []byte, err error) string {
	if err != nil {
		panic(err)
	}
	return string(b)
}

func main() {
	v := migration.Listing{}
	fmt.Println("v1:", must(jsonv1.Marshal(v)))
	fmt.Println("v2:", must(jsonv2.Marshal(v)))
	fmt.Println("v2 compatible:", must(migration.MarshalCompatible(v)))
	fmt.Println("v2 empty items:", must(migration.MarshalEmptyItems(v)))

	type Flags struct {
		Count   int  `json:"count,omitempty"`
		Enabled bool `json:"enabled,omitempty"`
	}
	fmt.Println("v1 omission:", must(jsonv1.Marshal(Flags{})))
	fmt.Println("v2 omission:", must(jsonv2.Marshal(Flags{})))

	type Role struct {
		Role string `json:"role"`
	}
	var old, next Role
	duplicate := []byte(`{"role":"viewer","role":"admin"}`)
	oldErr := jsonv1.Unmarshal(duplicate, &old)
	nextErr := jsonv2.Unmarshal(duplicate, &next)
	fmt.Printf("v1 duplicate: accepted=%t role=%s\n", oldErr == nil, old.Role)
	fmt.Printf("v2 duplicate: accepted=%t\n", nextErr == nil)
}
