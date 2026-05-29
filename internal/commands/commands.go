// Package commands xử lý 4 slash command: /today, /data, /announce, /help.
package commands

import (
	"context"
	"log"
	"strconv"
	"time"

	"github.com/bwmarrin/discordgo"

	"forexbot/internal/cache"
	"forexbot/internal/embeds"
	"forexbot/internal/models"
	"forexbot/internal/scheduler"
	"forexbot/internal/scraper"
)

// Handlers gom các phụ thuộc cho slash command.
type Handlers struct {
	Scraper   *scraper.Scraper
	Cache     *cache.Cache
	Scheduler *scheduler.Scheduler
}

// Definitions trả về định nghĩa 4 lệnh để đăng ký lên Discord.
func Definitions() []*discordgo.ApplicationCommand {
	return []*discordgo.ApplicationCommand{
		{Name: "today", Description: "Lấy các tin đặc biệt trong ngày hiện tại"},
		{
			Name:        "data",
			Description: "Lấy dữ liệu từ 1 đến 12 tháng gần nhất",
			Options: []*discordgo.ApplicationCommandOption{{
				Type:        discordgo.ApplicationCommandOptionInteger,
				Name:        "month",
				Description: "Các tháng để lấy dữ liệu trở về trước",
				Required:    true,
			}},
		},
		{Name: "announce", Description: "Thông báo ngay một mốc tin đã lên lịch trong ngày"},
		{Name: "help", Description: "Hiển thị hướng dẫn sử dụng bot"},
	}
}

// Today: cào lịch tin hôm nay (không lọc, giống bản gốc), chunk 15, trả embeds.
// Dùng deferred response vì cào qua FlareSolverr có thể >3s.
func (h *Handlers) Today(s *discordgo.Session, i *discordgo.InteractionCreate) {
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseDeferredChannelMessageWithSource,
	}); err != nil {
		log.Printf("[/today] defer lỗi: %v", err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 80*time.Second)
	defer cancel()

	events, err := h.Scraper.ParseTodayEvents(ctx, true)
	if err != nil {
		log.Printf("[/today] cào lỗi: %v", err)
		editError(s, i, "Tạm thời không lấy được dữ liệu, vui lòng thử lại sau.")
		return
	}

	emb := buildChunkEmbeds(events, 15, embeds.TodayEmbed)
	if _, err := s.InteractionResponseEdit(i.Interaction, &discordgo.WebhookEdit{Embeds: &emb}); err != nil {
		log.Printf("[/today] edit lỗi: %v", err)
	}
}

// Data: nhận tham số month (1..12), lưu vào cache theo interaction id, trả select
// menu chọn loại sự kiện. (Luồng tiếp theo do interactions xử lý.)
func (h *Handlers) Data(s *discordgo.Session, i *discordgo.InteractionCreate) {
	opts := i.ApplicationCommandData().Options
	month := 0
	if len(opts) > 0 {
		month = int(opts[0].IntValue())
	}

	if month < 1 || month > 12 {
		respondEphemeralEmbed(s, i, embeds.SimpleEmbed("CPI chỉ hỗ trợ thời gian từ 1 đến 12 tháng gần nhất", embeds.ColorRed))
		return
	}

	h.Cache.Set("interaction:data:"+i.Interaction.ID, models.DataState{Month: month}, cache.TTLDataPicker)

	row := embeds.SelectRow("event_for_data", "Lựa chọn loại sự kiện", embeds.Options(models.ImportantEventNames))
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{Components: []discordgo.MessageComponent{row}},
	}); err != nil {
		log.Printf("[/data] respond lỗi: %v", err)
	}
}

// Announce: liệt kê các job UpdateActivity còn chờ trong ngày để admin chọn chạy ngay.
func (h *Handlers) Announce(s *discordgo.Session, i *discordgo.InteractionCreate) {
	pending := h.Scheduler.PendingJobs()
	if len(pending) == 0 {
		em := embeds.SimpleEmbed("Không tìm thấy tin nào còn lại được lên lịch trong ngày hôm nay.", embeds.ColorRed)
		em.Title = "Thông báo !"
		respondEphemeralEmbed(s, i, em)
		return
	}

	options := make([]discordgo.SelectMenuOption, 0, len(pending))
	for _, j := range pending {
		options = append(options, discordgo.SelectMenuOption{Label: j.Timestamp, Value: strconv.Itoa(j.ID)})
	}
	row := embeds.SelectRow("custom_announce_timestamps", "Lựa chọn mốc thời gian", options)

	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Content:    "Vui lòng đối chiếu các mốc thời gian, chọn thời gian tin muốn thông báo **ngay lập tức**:",
			Components: []discordgo.MessageComponent{row},
			Flags:      discordgo.MessageFlagsEphemeral,
		},
	}); err != nil {
		log.Printf("[/announce] respond lỗi: %v", err)
	}
}

// Help: embed hướng dẫn (ephemeral).
func (h *Handlers) Help(s *discordgo.Session, i *discordgo.InteractionCreate) {
	em := &discordgo.MessageEmbed{
		Title: "Hướng dẫn sử dụng bot",
		Color: embeds.ColorGreen,
		Fields: []*discordgo.MessageEmbedField{
			{Name: "`/today`", Value: "Lấy các tin đặc biệt trong ngày hiện tại.", Inline: false},
			{Name: "`/data month:<1-12>`", Value: "Lấy dữ liệu kinh tế trong 1 đến 12 tháng gần nhất.", Inline: false},
			{Name: "Ví dụ", Value: "```/data month:3```", Inline: false},
		},
	}
	respondEphemeralEmbed(s, i, em)
}
