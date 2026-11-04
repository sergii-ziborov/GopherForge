package cursorlab

import (
	"context"
	"errors"
	"time"
)

var ErrLimit = errors.New("result limit exceeded")

type Label struct {
	Name string `bson:"name"`
}
type Cursor interface {
	Next(context.Context) bool
	Decode(any) error
	Err() error
	Close(context.Context) error
}

// ReadLabels takes ownership of c. It bounds returned document count, not
// MongoDB batch memory, document sizes, execution time or server work.
func ReadLabels(ctx context.Context, c Cursor, limit int) (rows []Label, err error) {
	defer func() {
		cleanup, cancel := context.WithTimeout(context.WithoutCancel(ctx), time.Second)
		defer cancel()
		err = errors.Join(err, c.Close(cleanup))
	}()
	if limit <= 0 {
		return nil, ErrLimit
	}
	for c.Next(ctx) {
		if len(rows) == limit {
			return rows, ErrLimit
		}
		var row Label
		if e := c.Decode(&row); e != nil {
			return rows, e
		}
		rows = append(rows, row)
	}
	if e := c.Err(); e != nil {
		return rows, e
	}
	if e := ctx.Err(); e != nil {
		return rows, e
	}
	return rows, nil
}
