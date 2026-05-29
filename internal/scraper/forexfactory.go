package scraper

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"

	"forexbot/internal/cache"
	"forexbot/internal/models"
	"forexbot/internal/timeutil"
)

const todayURL = "https://www.forexfactory.com/calendar?day=today"

var monthParams = []string{
	"jan", "feb", "mar", "apr", "may", "jun",
	"jul", "aug", "sep", "oct", "nov", "dec",
}

// Scraper cào và parse lịch ForexFactory, dùng FlareSolverr để vượt Cloudflare
// và cache để giảm số lần gọi (ForexFactory + FlareSolverr đều nặng/giới hạn).
type Scraper struct {
	flare *FlareSolverr
	cache *cache.Cache
}

// New tạo Scraper.
func New(flare *FlareSolverr, c *cache.Cache) *Scraper {
	return &Scraper{flare: flare, cache: c}
}

// ParseTodayEvents lấy lịch tin trong ngày hôm nay.
// useCache=true sẽ dùng lại HTML đã cache (TTL 10 phút) như bản Elixir.
func (s *Scraper) ParseTodayEvents(ctx context.Context, useCache bool) ([]models.Event, error) {
	key := "event" + timeutil.TodayID()

	var html string
	if useCache {
		if cached, ok := s.cache.GetString(key); ok {
			html = cached
		}
	}
	if html == "" {
		fetched, err := s.flare.Get(ctx, todayURL)
		if err != nil {
			return nil, err
		}
		html = fetched
		s.cache.Set(key, html, cache.TTLEventHTML)
	}

	raws, err := parseItems(html, todayURL)
	if err != nil {
		return nil, err
	}
	// Trang "today" thuộc về ngày hôm nay (giờ VN) — gán Date cho mọi sự kiện.
	today := timeutil.NowVN()
	today = time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, timeutil.VNLocation)
	events := make([]models.Event, 0, len(raws))
	for _, r := range raws {
		r.Date = today
		events = append(events, r.Event)
	}
	return events, nil
}

// ParseMonth lấy lịch của một tháng cụ thể (dùng cho dữ liệu CPI lịch sử).
// month: 1..12. Date của mỗi sự kiện được dựng từ (year, month, day-of-month).
func (s *Scraper) ParseMonth(ctx context.Context, month, year int) ([]models.Event, error) {
	if month < 1 || month > 12 {
		return nil, fmt.Errorf("tháng không hợp lệ: %d", month)
	}
	url := fmt.Sprintf("https://www.forexfactory.com/calendar?month=%s.%d", monthParams[month-1], year)

	html, err := s.flare.Get(ctx, url)
	if err != nil {
		return nil, err
	}
	raws, err := parseItems(html, url)
	if err != nil {
		return nil, err
	}

	// Dựng Date từ ngày-trong-tháng (đã forward-fill ở parseItems).
	out := make([]models.Event, 0, len(raws))
	for _, e := range raws {
		if e.dayOfMonth == 0 {
			continue // không xác định được ngày -> bỏ
		}
		e.Date = time.Date(year, time.Month(month), e.dayOfMonth, 0, 0, 0, 0, timeutil.VNLocation)
		out = append(out, e.Event)
	}
	return out, nil
}

// rawEvent là Event kèm ngày-trong-tháng tạm thời (chưa ghép year/month).
type rawEvent struct {
	models.Event
	dayOfMonth int
}

var dayRe = regexp.MustCompile(`(\d{1,2})`)

// parseItems parse toàn bộ dòng lịch từ HTML. baseURL dùng để dựng event_url.
func parseItems(html, baseURL string) ([]rawEvent, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil, fmt.Errorf("parse HTML lỗi: %w", err)
	}

	var events []rawEvent
	doc.Find("tr.calendar__row").Each(func(_ int, row *goquery.Selection) {
		if row.Find("td").Length() < 8 {
			return
		}

		name := strings.TrimSpace(row.Find("td.calendar__event .calendar__event-title").Text())
		if name == "" {
			return // bỏ các dòng không phải sự kiện (header ngày, v.v.)
		}

		eventID, _ := row.Attr("data-event-id")
		eventURL := baseURL
		if eventID != "" {
			eventURL = todayURL + "#detail=" + eventID
		}

		e := rawEvent{
			Event: models.Event{
				Time:      strings.TrimSpace(row.Find("td.calendar__time").Text()),
				Currency:  strings.TrimSpace(row.Find("td.calendar__currency").Text()),
				Impact:    extractImpact(row),
				EventName: name,
				Actual:    strings.TrimSpace(row.Find("td.calendar__actual").Text()),
				Forecast:  strings.TrimSpace(row.Find("td.calendar__forecast").Text()),
				Previous:  strings.TrimSpace(row.Find("td.calendar__previous").Text()),
				EventID:   eventID,
				EventURL:  eventURL,
			},
			dayOfMonth: extractDay(row),
		}
		events = append(events, e)
	})

	fillMissingTimes(events)
	fillMissingDays(events)
	return events, nil
}

// extractImpact đọc mức tác động từ class ff-impact-* trong ô impact.
func extractImpact(row *goquery.Selection) string {
	impact := "unknown"
	row.Find("td.calendar__impact span").EachWithBreak(func(_ int, span *goquery.Selection) bool {
		class, _ := span.Attr("class")
		switch {
		case strings.Contains(class, "ff-impact-red"):
			impact = "High"
		case strings.Contains(class, "ff-impact-ora"):
			impact = "Medium"
		case strings.Contains(class, "ff-impact-yel"):
			impact = "Low"
		case strings.Contains(class, "ff-impact-gra"):
			impact = "Non-Economic"
		default:
			return true // chưa thấy, xét span tiếp theo
		}
		return false // đã xác định -> dừng
	})
	return impact
}

// extractDay lấy ngày-trong-tháng từ ô ngày (vd "MonMay 26" -> 26). 0 nếu trống.
func extractDay(row *goquery.Selection) int {
	text := strings.TrimSpace(row.Find("td.calendar__date").Text())
	if text == "" {
		return 0
	}
	// Ngày là số 1-2 chữ số cuối cùng trong chuỗi.
	matches := dayRe.FindAllString(text, -1)
	if len(matches) == 0 {
		return 0
	}
	d, err := strconv.Atoi(matches[len(matches)-1])
	if err != nil || d < 1 || d > 31 {
		return 0
	}
	return d
}

// fillMissingTimes forward-fill giờ rỗng bằng giờ của dòng trước
// (ForexFactory chỉ hiện giờ ở dòng đầu mỗi mốc).
func fillMissingTimes(events []rawEvent) {
	last := ""
	for i := range events {
		if events[i].Time == "" {
			events[i].Time = last
		} else {
			last = events[i].Time
		}
	}
}

// fillMissingDays forward-fill ngày rỗng bằng ngày của dòng trước
// (ForexFactory chỉ hiện ngày ở dòng đầu mỗi nhóm ngày).
func fillMissingDays(events []rawEvent) {
	last := 0
	for i := range events {
		if events[i].dayOfMonth == 0 {
			events[i].dayOfMonth = last
		} else {
			last = events[i].dayOfMonth
		}
	}
}
