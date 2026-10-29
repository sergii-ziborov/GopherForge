package examples

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"io"
	"sync/atomic"
	"testing"
	"time"
)

// This deliberately tiny local driver checks ownership, not PostgreSQL semantics.
type fakeState struct {
	rowsClosed         atomic.Bool
	commits, rollbacks atomic.Int32
	affected           int64
	commitErr          error
}
type connector struct{ state *fakeState }

func (c connector) Connect(context.Context) (driver.Conn, error) { return &conn{c.state}, nil }
func (c connector) Driver() driver.Driver                        { return fakeDriver{} }

type fakeDriver struct{}

func (fakeDriver) Open(string) (driver.Conn, error) { return nil, errors.New("use connector") }

type conn struct{ s *fakeState }

func (c *conn) Prepare(string) (driver.Stmt, error)                          { return nil, errors.New("unexpected prepare") }
func (c *conn) Close() error                                                 { return nil }
func (c *conn) Begin() (driver.Tx, error)                                    { return &transaction{c.s}, nil }
func (c *conn) BeginTx(context.Context, driver.TxOptions) (driver.Tx, error) { return c.Begin() }
func (c *conn) QueryContext(context.Context, string, []driver.NamedValue) (driver.Rows, error) {
	return &resultRows{s: c.s}, nil
}
func (c *conn) ExecContext(context.Context, string, []driver.NamedValue) (driver.Result, error) {
	return driver.RowsAffected(c.s.affected), nil
}

type transaction struct{ s *fakeState }

func (t *transaction) Commit() error   { t.s.commits.Add(1); return t.s.commitErr }
func (t *transaction) Rollback() error { t.s.rollbacks.Add(1); return nil }

type resultRows struct {
	s     *fakeState
	index int
}

func (r *resultRows) Columns() []string { return []string{"id"} }
func (r *resultRows) Close() error      { r.s.rowsClosed.Store(true); return nil }
func (r *resultRows) Next(v []driver.Value) error {
	if r.index == 2 {
		return io.EOF
	}
	r.index++
	v[0] = int64(r.index)
	return nil
}
func TestRowsReturnConnection(t *testing.T) {
	s := &fakeState{}
	db := sql.OpenDB(connector{s})
	defer db.Close()
	configurePool(db)
	ids, e := loadIDs(context.Background(), db)
	if e != nil {
		t.Fatal(e)
	}
	if len(ids) != 2 || ids[0] != 1 || ids[1] != 2 {
		t.Fatalf("IDs %v", ids)
	}
	if !s.rowsClosed.Load() || db.Stats().InUse != 0 {
		t.Fatal("rows retained pool connection")
	}
}
func TestTransactionOutcomes(t *testing.T) {
	rejected := errors.New("commit rejected")
	for _, tc := range []struct {
		name                     string
		n                        int64
		commitErr                error
		wantCommit, wantRollback int32
	}{
		{"unavailable", 0, nil, 0, 1}, {"committed", 1, nil, 1, 0}, {"commit error", 1, rejected, 1, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := &fakeState{affected: tc.n, commitErr: tc.commitErr}
			db := sql.OpenDB(connector{s})
			defer db.Close()
			e := reserve(context.Background(), db, "widget")
			if tc.n == 0 && e == nil {
				t.Fatal("unavailable stock accepted")
			}
			if tc.commitErr != nil && !errors.Is(e, tc.commitErr) {
				t.Fatalf("lost commit error: %v", e)
			}
			if s.commits.Load() != tc.wantCommit || s.rollbacks.Load() != tc.wantRollback {
				t.Fatal("wrong transaction owner")
			}
			if db.Stats().InUse != 0 {
				t.Fatal("transaction retained connection")
			}
		})
	}
}
func TestCancelledPoolWaitDoesNotOpenAnotherConnection(t *testing.T) {
	db := sql.OpenDB(connector{&fakeState{}})
	defer db.Close()
	db.SetMaxOpenConns(1)
	held, e := db.Conn(context.Background())
	if e != nil {
		t.Fatal(e)
	}
	defer held.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	result := make(chan error, 1)
	go func() {
		acquired, err := db.Conn(ctx)
		if acquired != nil {
			_ = acquired.Close()
		}
		result <- err
	}()
	ticker := time.NewTicker(time.Millisecond)
	defer ticker.Stop()
	deadline := time.NewTimer(2 * time.Second)
	defer deadline.Stop()
	for db.Stats().WaitCount == 0 {
		select {
		case <-ticker.C:
		case <-deadline.C:
			t.Fatal("second acquisition never entered pool wait")
		}
	}
	cancel()
	select {
	case e = <-result:
	case <-deadline.C:
		t.Fatal("cancelled pool acquisition did not return")
	}
	if !errors.Is(e, context.Canceled) {
		t.Fatalf("got %v", e)
	}
	if db.Stats().OpenConnections != 1 {
		t.Fatal("pool cap bypassed")
	}
}
