package migration

import (
	jsonv1 "encoding/json"
	jsonv2 "encoding/json/v2"
	"fmt"
	"strings"
)

type Listing struct {
	Items  []string          `json:"items"`
	Labels map[string]string `json:"labels"`
}

// MarshalCompatible moves to the v2 API while retaining v1 behavior.
func MarshalCompatible(v Listing) ([]byte, error) {
	return jsonv2.Marshal(v, jsonv1.DefaultOptionsV1())
}

// MarshalEmptyItems opts into one deliberate contract change.
func MarshalEmptyItems(v Listing) ([]byte, error) {
	return jsonv2.Marshal(v,
		jsonv1.DefaultOptionsV1(),
		jsonv2.FormatNilSliceAsNull(false),
	)
}

type Update struct {
	Name    string `json:"name"`
	Enabled bool   `json:"enabled"`
}

// DecodeUpdate publishes a value only after syntax, shape and domain checks.
// The caller must bound data size before decoding. This is a full update,
// not a PATCH representation that distinguishes absent, null and false.
func DecodeUpdate(data []byte) (Update, error) {
	var next Update
	if err := jsonv2.Unmarshal(data, &next,
		jsonv2.RejectUnknownMembers(true)); err != nil {
		return Update{}, fmt.Errorf("decode update: %w", err)
	}
	if strings.TrimSpace(next.Name) == "" {
		return Update{}, fmt.Errorf("name must not be blank")
	}
	return next, nil
}
