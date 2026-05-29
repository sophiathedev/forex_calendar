// Package config nạp cấu hình từ biến môi trường (và file .env nếu có).
// Tương đương config/runtime.exs trong bản Elixir.
package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

// Config gom toàn bộ tham số runtime của bot.
type Config struct {
	DiscordToken    string // bắt buộc
	GuildID         string // bắt buộc — snowflake dạng string
	ChannelID       string // bắt buộc — channel bot tự đăng tin
	FlareSolverrURL string // mặc định http://localhost:8191
}

// Load đọc .env (nếu tồn tại) rồi lấy biến môi trường. Fail-fast nếu thiếu
// biến bắt buộc, giống System.fetch_env! của bản gốc.
func Load() (*Config, error) {
	// .env là tuỳ chọn cho dev; bỏ qua lỗi nếu không có file.
	_ = godotenv.Load()

	cfg := &Config{
		DiscordToken:    os.Getenv("DISCORD_TOKEN"),
		GuildID:         os.Getenv("GUILD_ID"),
		ChannelID:       os.Getenv("CHANNEL_ID"),
		FlareSolverrURL: os.Getenv("FLARESOLVERR_URL"),
	}

	var missing []string
	if cfg.DiscordToken == "" {
		missing = append(missing, "DISCORD_TOKEN")
	}
	if cfg.GuildID == "" {
		missing = append(missing, "GUILD_ID")
	}
	if cfg.ChannelID == "" {
		missing = append(missing, "CHANNEL_ID")
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("thiếu biến môi trường bắt buộc: %v", missing)
	}

	if cfg.FlareSolverrURL == "" {
		cfg.FlareSolverrURL = "http://localhost:8191"
	}

	return cfg, nil
}
