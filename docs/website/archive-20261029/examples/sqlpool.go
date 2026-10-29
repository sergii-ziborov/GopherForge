package examples

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

func configurePool(db *sql.DB) {
	// Illustrative values: derive these from deployment and DB budgets.
	db.SetMaxOpenConns(12)
	db.SetMaxIdleConns(6)
	db.SetConnMaxIdleTime(2 * time.Minute)
	db.SetConnMaxLifetime(20 * time.Minute)
}

func loadIDs(ctx context.Context, db *sql.DB) ([]int64, error) {
	rows, err := db.QueryContext(ctx,
		`SELECT id FROM orders ORDER BY id LIMIT 100`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make([]int64, 0, 100)
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return ids, nil
}

func reserve(ctx context.Context, db *sql.DB, sku string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	result, err := tx.ExecContext(ctx,
		`UPDATE stock SET available = available - 1
         WHERE sku = $1 AND available > 0`, sku)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if n != 1 {
		return errors.New("item unavailable")
	}
	return tx.Commit()
}
