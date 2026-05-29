// Package models định nghĩa kiểu dữ liệu sự kiện kinh tế và các danh sách lọc
// dùng chung. Tương đương ForexBot.Types.Event, đồng thời gom các whitelist mà
// bản Elixir để trùng lặp ở slash/data.ex và jobs/cpi.ex về một nguồn duy nhất.
package models

import (
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Event là một dòng tin trong lịch ForexFactory.
type Event struct {
	Time      string    // hiển thị gốc, ví dụ "8:30am", "All Day", "Tentative"
	Date      time.Time // ngày của sự kiện (đã parse); zero nếu chưa xác định
	Currency  string    // USD, EUR, ...
	Impact    string    // High / Medium / Low / Non-Economic
	EventName string
	Actual    string
	Forecast  string
	Previous  string
	EventID   string
	EventURL  string
}

// ImportantCurrencies — 4 đồng tiền bot quan tâm.
var ImportantCurrencies = []string{"USD", "EUR", "GBP", "JPY"}

// ImportantImpacts — mức tác động được coi là đáng chú ý.
var ImportantImpacts = []string{"High", "Non-Economic"}

// ImportantEventNames — whitelist sự kiện kinh tế cho /data và job Cpi.
// Đây là NGUỒN DUY NHẤT; mọi nơi cần danh sách này phải dùng biến này.
var ImportantEventNames = []string{
	"Core CPI m/m",
	"CPI m/m",
	"CPI y/y",
	"Core PPI m/m",
	"PPI m/m",
	"Core Retail Sales m/m",
	"Retail Sales m/m",
	"Prelim UoM Consumer Sentiment",
	"Prelim UoM Inflation Expectations",
	"ADP Non-Farm Employment Change",
	"Non-Farm Employment Change",
	"Unemployment Claims",
	"Unemployment Rate",
	"ISM Manufacturing PMI",
	"ISM Services PMI",
	"FOMC Economic Projections",
	"FOMC Statement",
	"FOMC Press Conference",
	"Average Hourly Earnings m/m",
	"Federal Funds Rate",
	"ECB Press Conference",
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

// IsImportantCurrency / IsImportantImpact / IsImportantEventName — kiểm tra whitelist.
func IsImportantCurrency(c string) bool  { return contains(ImportantCurrencies, c) }
func IsImportantImpact(i string) bool    { return contains(ImportantImpacts, i) }
func IsImportantEventName(n string) bool { return contains(ImportantEventNames, n) }

// FilterImportant lọc các sự kiện theo tiền tệ + impact quan trọng.
// Tương đương filter_important_events/1 trong today.ex (chỉ lọc currency + impact).
func FilterImportant(events []Event) []Event {
	out := make([]Event, 0, len(events))
	for _, e := range events {
		if IsImportantCurrency(e.Currency) && IsImportantImpact(e.Impact) {
			out = append(out, e)
		}
	}
	return out
}

// FilterImportantNamed lọc thêm theo whitelist tên sự kiện (dùng cho job Cpi/dữ liệu lịch sử).
func FilterImportantNamed(events []Event) []Event {
	out := make([]Event, 0, len(events))
	for _, e := range FilterImportant(events) {
		if IsImportantEventName(e.EventName) {
			out = append(out, e)
		}
	}
	return out
}

// Chunk chia danh sách sự kiện thành các nhóm tối đa size phần tử
// (Discord giới hạn 25 field/embed nên bot chia 15 hoặc 9 mỗi embed).
func Chunk(events []Event, size int) [][]Event {
	if size <= 0 {
		return [][]Event{events}
	}
	var out [][]Event
	for i := 0; i < len(events); i += size {
		end := i + size
		if end > len(events) {
			end = len(events)
		}
		out = append(out, events[i:end])
	}
	return out
}

var timeRe = regexp.MustCompile(`^(\d{1,2}):(\d{2})(am|pm)$`)

// ConvertTime24h parse chuỗi giờ kiểu "8:30am" -> (hour, minute, ok).
// Trả ok=false cho "All Day", "Tentative", rỗng, hay định dạng lạ
// (tương đương convert_time_24_hours/1 trả {-1,-1} khi lỗi).
func ConvertTime24h(s string) (hour, minute int, ok bool) {
	m := timeRe.FindStringSubmatch(strings.ToLower(strings.TrimSpace(s)))
	if m == nil {
		return -1, -1, false
	}
	h, _ := strconv.Atoi(m[1])
	min, _ := strconv.Atoi(m[2])
	switch m[3] {
	case "am":
		if h == 12 {
			h = 0
		}
	case "pm":
		if h != 12 {
			h += 12
		}
	}
	return h, min, true
}
