// Package embeds dựng các embed và component Discord dùng chung cho slash
// command, interaction và job nền — gom về một nơi để tránh lặp như bản Elixir
// (create_embed/put_events bị lặp ở today.ex, data.ex, update_activity.ex).
package embeds

import (
	"fmt"
	"strings"

	"github.com/bwmarrin/discordgo"

	"forexbot/internal/models"
	"forexbot/internal/timeutil"
)

// Màu sắc dùng chung.
const (
	ColorBlue  = 0x4285F4
	ColorGreen = 0x32A852
	ColorRed   = 0xEB4034
)

const footer = "Powered by Go discordgo."

// Style nút (discordgo dùng iota; gói lại cho dễ đọc, khớp style bản Elixir).
const (
	styleSecondary = discordgo.SecondaryButton // style 2 (xám) — nút thông tin
	styleSuccess   = discordgo.SuccessButton   // style 3 (xanh) — nút điều hướng
)

// AllowedCurrencies — dùng cho select menu chọn tiền tệ.
var AllowedCurrencies = []string{"USD", "EUR", "GBP", "JPY"}

func impactEmoji(impact string) string {
	switch impact {
	case "High":
		return ":red_circle:"
	case "Medium":
		return ":orange_circle:"
	case "Low":
		return ":yellow_circle:"
	default:
		return ":white_circle:"
	}
}

func currencyEmoji(cur string) string {
	switch cur {
	case "USD":
		return ":flag_us:"
	case "EUR":
		return ":flag_eu:"
	case "GBP":
		return ":flag_gb:"
	case "JPY":
		return ":flag_jp:"
	default:
		return ""
	}
}

func footerObj() *discordgo.MessageEmbedFooter {
	return &discordgo.MessageEmbedFooter{Text: footer}
}

// newsField dựng một field tin đầy đủ (actual/forecast/previous) — dùng cho
// /today và job "tin mới gần đây".
func newsField(e models.Event) *discordgo.MessageEmbedField {
	value := strings.Join([]string{
		fmt.Sprintf("%s %s Impact ([Details](%s))", impactEmoji(e.Impact), e.Impact, e.EventURL),
		fmt.Sprintf("```Actual: %s", e.Actual),
		fmt.Sprintf("Forecast: %s", e.Forecast),
		fmt.Sprintf("Previous: %s```", e.Previous),
	}, "\n")
	return &discordgo.MessageEmbedField{
		Name:   fmt.Sprintf("`%s` %s %s - %s", e.Time, currencyEmoji(e.Currency), e.Currency, e.EventName),
		Value:  value,
		Inline: true,
	}
}

// TodayEmbed dựng embed lịch tin trong ngày.
func TodayEmbed(events []models.Event) *discordgo.MessageEmbed {
	return newsEmbed(fmt.Sprintf("Forex News Today - %s", todayString()), events)
}

// ActivityEmbed dựng embed "tin mới gần đây".
func ActivityEmbed(events []models.Event) *discordgo.MessageEmbed {
	return newsEmbed(fmt.Sprintf("Tin mới gần đây - %s", todayString()), events)
}

func newsEmbed(title string, events []models.Event) *discordgo.MessageEmbed {
	em := &discordgo.MessageEmbed{Title: title, Color: ColorBlue, Footer: footerObj()}
	if len(events) == 0 {
		em.Description = "Hiện tại không có tin nào đặc biệt."
		return em
	}
	for _, e := range events {
		em.Fields = append(em.Fields, newsField(e))
	}
	return em
}

// DataEmbed dựng embed dữ liệu lịch sử (kèm ngày, chỉ hiển thị Actual).
func DataEmbed(events []models.Event) *discordgo.MessageEmbed {
	em := &discordgo.MessageEmbed{Title: "Forex Data", Color: ColorBlue}
	if len(events) == 0 {
		em.Description = "Không có data."
		return em
	}
	for _, e := range events {
		date := e.Date.Format("2006/01/02")
		value := strings.Join([]string{
			fmt.Sprintf("%s %s ([Details](%s))", impactEmoji(e.Impact), e.Impact, e.EventURL),
			fmt.Sprintf("```Actual: %s```", e.Actual),
		}, "\n")
		em.Fields = append(em.Fields, &discordgo.MessageEmbedField{
			Name:   fmt.Sprintf("`%s %s` %s %s - %s", date, e.Time, currencyEmoji(e.Currency), e.Currency, e.EventName),
			Value:  value,
			Inline: true,
		})
	}
	return em
}

// SimpleEmbed dựng embed chỉ có mô tả + màu (dùng cho thông báo lỗi/thành công).
func SimpleEmbed(description string, color int) *discordgo.MessageEmbed {
	return &discordgo.MessageEmbed{Description: description, Color: color}
}

// PaginationRow dựng hàng nút phân trang << < x/y > >>.
func PaginationRow(page, total int) discordgo.ActionsRow {
	leftDisabled := page == 0
	rightDisabled := page >= total-1
	return discordgo.ActionsRow{Components: []discordgo.MessageComponent{
		discordgo.Button{Label: "<<", CustomID: "first_prev", Style: styleSuccess, Disabled: leftDisabled},
		discordgo.Button{Label: "<", CustomID: "prev_page", Style: styleSuccess, Disabled: leftDisabled},
		discordgo.Button{Label: fmt.Sprintf("%d / %d", page+1, total), CustomID: "page_info", Style: styleSecondary, Disabled: true},
		discordgo.Button{Label: ">", CustomID: "next_page", Style: styleSuccess, Disabled: rightDisabled},
		discordgo.Button{Label: ">>", CustomID: "last_next", Style: styleSuccess, Disabled: rightDisabled},
	}}
}

// SelectRow dựng một action row chứa một select menu.
func SelectRow(customID, placeholder string, options []discordgo.SelectMenuOption) discordgo.ActionsRow {
	minV := 1
	return discordgo.ActionsRow{Components: []discordgo.MessageComponent{
		discordgo.SelectMenu{
			CustomID:    customID,
			Placeholder: placeholder,
			MinValues:   &minV,
			MaxValues:   1,
			Options:     options,
		},
	}}
}

// Options tiện ích dựng option select menu từ list nhãn=giá trị giống nhau.
func Options(values []string) []discordgo.SelectMenuOption {
	out := make([]discordgo.SelectMenuOption, 0, len(values))
	for _, v := range values {
		out = append(out, discordgo.SelectMenuOption{Label: v, Value: v})
	}
	return out
}

func todayString() string {
	return timeutil.NowVN().Format("2006/01/02")
}
