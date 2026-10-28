// Package database は MySQL(GORM)接続の初期化。
package database

import (
	"time"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/config"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Open は GORM の *gorm.DB を初期化して返す。
//
// Connection Pool を明示設定し、接続の使い回しと枯渇を制御する。
// AutoMigrate は実行しない（スキーマは golang-migrate で管理するため）。
func Open(cfg config.Config) (*gorm.DB, error) {
	gormCfg := &gorm.Config{
		// SQL をそのままログへ出すと接続情報やデータが漏れるため、警告レベルに抑える。
		Logger: logger.Default.LogMode(logger.Warn),
	}

	db, err := gorm.Open(mysql.Open(cfg.DSN()), gormCfg)
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	// Connection Pool 設定（ローカル開発向けの控えめな値）。
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(5 * time.Minute)

	return db, nil
}
