// Command bot là điểm khởi chạy ForexBot (bản Go). Tương đương ForexBot.Application.
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/bwmarrin/discordgo"

	"forexbot/internal/cache"
	"forexbot/internal/commands"
	"forexbot/internal/config"
	"forexbot/internal/discord"
	"forexbot/internal/interactions"
	"forexbot/internal/scheduler"
	"forexbot/internal/scraper"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Cấu hình lỗi: %v", err)
	}

	c := cache.New()

	// FlareSolverr: chờ service sẵn sàng (tránh race lúc compose vừa khởi động,
	// FlareSolverr còn đang boot Chromium), rồi tạo session để tái dùng.
	flare := scraper.NewFlareSolverr(cfg.FlareSolverrURL)
	readyCtx, readyCancel := context.WithTimeout(context.Background(), 2*time.Minute)
	if err := flare.WaitReady(readyCtx); err != nil {
		log.Printf("Chờ FlareSolverr không thành công (vẫn tiếp tục, job sẽ tự thử lại): %v", err)
	} else {
		log.Println("FlareSolverr đã sẵn sàng")
	}
	readyCancel()

	sessCtx, sessCancel := context.WithTimeout(context.Background(), 90*time.Second)
	if err := flare.CreateSession(sessCtx); err != nil {
		log.Printf("Không tạo được session FlareSolverr (vẫn tiếp tục): %v", err)
	}
	sessCancel()

	sc := scraper.New(flare, c)

	// Session Discord được tạo trước để scheduler dùng chung.
	session, err := discordgo.New("Bot " + cfg.DiscordToken)
	if err != nil {
		log.Fatalf("Tạo session Discord lỗi: %v", err)
	}

	sched := scheduler.New(session, sc, c, cfg.ChannelID)

	cmdHandlers := &commands.Handlers{Scraper: sc, Cache: c, Scheduler: sched}
	interHandlers := &interactions.Handlers{Cache: c, Scheduler: sched}

	bot := discord.NewBot(session, cfg.GuildID, cmdHandlers, interHandlers)
	if err := bot.Open(); err != nil {
		log.Fatalf("Mở kết nối Discord lỗi: %v", err)
	}
	defer bot.Close()

	if err := sched.Start(); err != nil {
		log.Fatalf("Khởi động scheduler lỗi: %v", err)
	}
	defer sched.Stop()

	// Chạy ngay khi boot (giống Application insert ResetDaily + Cpi lúc start).
	go sched.RunResetDaily()
	go sched.RunCpi()

	log.Println("ForexBot đang chạy. Nhấn Ctrl+C để thoát.")
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Println("Đang tắt...")
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutCancel()
	flare.DestroySession(shutCtx)
}
