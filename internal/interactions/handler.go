// Package interactions xử lý các tương tác component (select menu, nút) — luồng
// /data nhiều bước, phân trang, và nút "announce ngay". Tương đương
// ForexBot.InteractionHandler.
package interactions

import (
	"log"
	"strconv"
	"time"

	"github.com/bwmarrin/discordgo"

	"forexbot/internal/cache"
	"forexbot/internal/embeds"
	"forexbot/internal/models"
	"forexbot/internal/scheduler"
	"forexbot/internal/timeutil"
)

// Handlers gom phụ thuộc cho các interaction component.
type Handlers struct {
	Cache     *cache.Cache
	Scheduler *scheduler.Scheduler
}

// paginationState lưu danh sách embed đã dựng sẵn và trang hiện tại.
type paginationState struct {
	Embeds []*discordgo.MessageEmbed
	Page   int
}

// Handle định tuyến theo custom_id của component.
func (h *Handlers) Handle(s *discordgo.Session, i *discordgo.InteractionCreate) {
	switch i.MessageComponentData().CustomID {
	case "event_for_data":
		h.eventForData(s, i)
	case "currency_for_data":
		h.currencyForData(s, i)
	case "next_page":
		h.paginate(s, i, func(p, total int) int { return min(p+1, total-1) })
	case "prev_page":
		h.paginate(s, i, func(p, _ int) int { return max(p-1, 0) })
	case "first_prev":
		h.paginate(s, i, func(_, _ int) int { return 0 })
	case "last_next":
		h.paginate(s, i, func(_, total int) int { return total - 1 })
	case "custom_announce_timestamps":
		h.announceNow(s, i)
	default:
		// page_info và các nút disabled khác: không làm gì.
	}
}

func (h *Handlers) dataKey(i *discordgo.InteractionCreate) string {
	return "interaction:data:" + i.Message.Interaction.ID
}

func (h *Handlers) pageKey(i *discordgo.InteractionCreate) string {
	return "interaction:pagination:" + i.Message.Interaction.ID
}

// eventForData: lưu loại sự kiện đã chọn, hỏi tiếp loại tiền tệ.
func (h *Handlers) eventForData(s *discordgo.Session, i *discordgo.InteractionCreate) {
	v, ok := h.Cache.Get(h.dataKey(i))
	state, _ := v.(models.DataState)
	if !ok {
		expired(s, i)
		return
	}
	state.EventName = i.MessageComponentData().Values[0]
	h.Cache.Set(h.dataKey(i), state, cache.TTLDataPicker)

	row := embeds.SelectRow("currency_for_data", "Lựa chọn loại tiền tệ", embeds.Options(embeds.AllowedCurrencies))
	updateMessage(s, i, nil, []discordgo.MessageComponent{row})
}

// currencyForData: lọc cpi_data theo state, dựng embed phân trang, hiển thị trang đầu.
func (h *Handlers) currencyForData(s *discordgo.Session, i *discordgo.InteractionCreate) {
	v, ok := h.Cache.Get(h.dataKey(i))
	state, _ := v.(models.DataState)
	if !ok {
		expired(s, i)
		return
	}
	state.Currency = i.MessageComponentData().Values[0]

	dataAny, _ := h.Cache.Get("cpi_data")
	data, _ := dataAny.([]models.Event)

	start, end := dateRange(state.Month)
	var filtered []models.Event
	for _, e := range data {
		if e.Date.Before(start) || e.Date.After(end) {
			continue
		}
		if e.EventName == state.EventName && e.Currency == state.Currency {
			filtered = append(filtered, e)
		}
	}

	chunks := models.Chunk(filtered, 9)
	pages := make([]*discordgo.MessageEmbed, 0, len(chunks))
	for _, ch := range chunks {
		pages = append(pages, embeds.DataEmbed(ch))
	}

	if len(pages) == 0 {
		updateMessage(s, i, []*discordgo.MessageEmbed{embeds.DataEmbed(nil)}, []discordgo.MessageComponent{})
		return
	}

	h.Cache.Set(h.pageKey(i), paginationState{Embeds: pages, Page: 0}, cache.TTLPagination)
	row := embeds.PaginationRow(0, len(pages))
	updateMessage(s, i, []*discordgo.MessageEmbed{pages[0]}, []discordgo.MessageComponent{row})
}

// paginate cập nhật trang theo hàm tính trang mới rồi render lại.
func (h *Handlers) paginate(s *discordgo.Session, i *discordgo.InteractionCreate, next func(page, total int) int) {
	v, ok := h.Cache.Get(h.pageKey(i))
	st, ok2 := v.(paginationState)
	if !ok || !ok2 {
		expired(s, i)
		return
	}
	st.Page = next(st.Page, len(st.Embeds))
	h.Cache.Set(h.pageKey(i), st, cache.TTLPagination)

	row := embeds.PaginationRow(st.Page, len(st.Embeds))
	updateMessage(s, i, []*discordgo.MessageEmbed{st.Embeds[st.Page]}, []discordgo.MessageComponent{row})
}

// announceNow: chạy ngay job UpdateActivity đã chọn.
func (h *Handlers) announceNow(s *discordgo.Session, i *discordgo.InteractionCreate) {
	id, err := strconv.Atoi(i.MessageComponentData().Values[0])
	if err != nil {
		expired(s, i)
		return
	}
	h.Scheduler.TriggerNow(id)

	em := embeds.SimpleEmbed("Thao tác thành công !", embeds.ColorGreen)
	em.Title = "Thông báo !"
	em.Footer = &discordgo.MessageEmbedFooter{Text: "Powered by Go discordgo."}
	updateMessage(s, i, []*discordgo.MessageEmbed{em}, []discordgo.MessageComponent{})
}

// dateRange trả [đầu tháng cách đây `month` tháng, cuối tháng trước] theo giờ VN.
func dateRange(month int) (time.Time, time.Time) {
	now := timeutil.NowVN()
	firstOfThisMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, timeutil.VNLocation)
	start := firstOfThisMonth.AddDate(0, -month, 0)
	end := firstOfThisMonth.AddDate(0, 0, -1)
	return start, end
}

// updateMessage trả lời kiểu cập nhật message hiện tại (interaction type 7).
func updateMessage(s *discordgo.Session, i *discordgo.InteractionCreate, embedList []*discordgo.MessageEmbed, components []discordgo.MessageComponent) {
	data := &discordgo.InteractionResponseData{Components: components}
	if embedList != nil {
		data.Embeds = embedList
	}
	if err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseUpdateMessage,
		Data: data,
	}); err != nil {
		log.Printf("[interaction] update lỗi: %v", err)
	}
}

// expired trả embed "tương tác đã hết hạn" dạng ephemeral.
func expired(s *discordgo.Session, i *discordgo.InteractionCreate) {
	_ = s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: &discordgo.InteractionResponseData{
			Embeds: []*discordgo.MessageEmbed{embeds.SimpleEmbed("Tương tác đã hết hạn, vui lòng thử lại.", embeds.ColorRed)},
			Flags:  discordgo.MessageFlagsEphemeral,
		},
	})
}
