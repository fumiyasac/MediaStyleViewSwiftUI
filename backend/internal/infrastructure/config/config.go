// Package config は環境変数からの設定読み込みと検証。
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config はアプリ全体の設定。
type Config struct {
	AppEnv   string
	HTTPPort string

	MySQLHost     string
	MySQLPort     string
	MySQLDatabase string
	MySQLUser     string
	MySQLPassword string
}

// Load は環境変数から設定を読み込み、必須項目を検証する。
//
// 設定不足や不正値があれば分かりやすいエラーを返す（起動を中断させる）。
// パスワードや DSN はここでも返り値に含むが、ログへは出力しない（呼び出し側で出さない運用）。
func Load() (Config, error) {
	cfg := Config{
		AppEnv:        getEnv("APP_ENV", "development"),
		HTTPPort:      getEnv("HTTP_PORT", "8080"),
		MySQLHost:     os.Getenv("MYSQL_HOST"),
		MySQLPort:     getEnv("MYSQL_PORT", "3306"),
		MySQLDatabase: os.Getenv("MYSQL_DATABASE"),
		MySQLUser:     os.Getenv("MYSQL_USER"),
		MySQLPassword: os.Getenv("MYSQL_PASSWORD"),
	}

	// 必須項目の検証（不足はキー名を明示してエラー）。
	missing := []string{}
	if cfg.MySQLHost == "" {
		missing = append(missing, "MYSQL_HOST")
	}
	if cfg.MySQLDatabase == "" {
		missing = append(missing, "MYSQL_DATABASE")
	}
	if cfg.MySQLUser == "" {
		missing = append(missing, "MYSQL_USER")
	}
	if cfg.MySQLPassword == "" {
		missing = append(missing, "MYSQL_PASSWORD")
	}
	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required environment variables: %v", missing)
	}

	// ポート番号の形式チェック。
	if _, err := strconv.Atoi(cfg.HTTPPort); err != nil {
		return Config{}, fmt.Errorf("HTTP_PORT must be numeric: %q", cfg.HTTPPort)
	}
	if _, err := strconv.Atoi(cfg.MySQLPort); err != nil {
		return Config{}, fmt.Errorf("MYSQL_PORT must be numeric: %q", cfg.MySQLPort)
	}

	return cfg, nil
}

// DSN は GORM(go-sql-driver/mysql)用の接続文字列を組み立てる。
//
// 文字コードは utf8mb4（日本語が壊れないように）。
// parseTime=true で DATETIME/DATE を time.Time に、loc=UTC で日付のズレを防ぐ。
// この文字列はパスワードを含むためログへ出力しない。
func (c Config) DSN() string {
	return fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=true&loc=UTC",
		c.MySQLUser, c.MySQLPassword, c.MySQLHost, c.MySQLPort, c.MySQLDatabase,
	)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
