// Package discord wiring discordgo session: đăng ký lệnh khi READY và định tuyến
// interaction. Tương đương ForexBot.Consumer.
package discord

import (
	"log"

	"github.com/bwmarrin/discordgo"

	"forexbot/internal/commands"
	"forexbot/internal/interactions"
)

// Bot bọc session và các handler.
type Bot struct {
	Session      *discordgo.Session
	guildID      string
	commands     *commands.Handlers
	interactions *interactions.Handlers
}

// NewBot gắn handler lên session sẵn có (session được tạo ở main để scheduler
// có thể dùng chung trước khi Open).
func NewBot(s *discordgo.Session, guildID string, cmd *commands.Handlers, inter *interactions.Handlers) *Bot {
	// Chỉ cần IntentsGuilds: slash command/interaction tới qua gateway không cần
	// intent, đăng/sửa/xoá message dùng REST. Tránh IntentsAll vì nó kéo theo
	// privileged intents (Message Content/Members/Presence) — không bật trong
	// Developer Portal sẽ bị từ chối kết nối (code 4014).
	s.Identify.Intents = discordgo.IntentsGuilds
	b := &Bot{Session: s, guildID: guildID, commands: cmd, interactions: inter}
	s.AddHandler(b.onReady)
	s.AddHandler(b.onInteraction)
	return b
}

// Open mở kết nối gateway.
func (b *Bot) Open() error { return b.Session.Open() }

// Close đóng kết nối gateway.
func (b *Bot) Close() error { return b.Session.Close() }

// onReady đăng ký 4 slash command vào guild khi bot sẵn sàng.
func (b *Bot) onReady(s *discordgo.Session, _ *discordgo.Ready) {
	log.Println("Bot is ready!")
	cmds, err := s.ApplicationCommandBulkOverwrite(s.State.User.ID, b.guildID, commands.Definitions())
	if err != nil {
		log.Printf("Đăng ký lệnh lỗi: %v", err)
		return
	}
	for _, c := range cmds {
		log.Printf("Registered command: %s", c.Name)
	}
}
