package scraper

import (
	"encoding/json"
	"os"
	"testing"
)

// TestParseLiveHTML là test thủ công: chạy parseItems trên HTML thật do
// FlareSolverr trả về (lưu ở /tmp/flare_resp.json). Bỏ qua nếu file không có.
// Dùng để kiểm tra selector khớp markup thực tế của ForexFactory.
func TestParseLiveHTML(t *testing.T) {
	raw, err := os.ReadFile("/tmp/flare_resp.json")
	if err != nil {
		t.Skip("không có /tmp/flare_resp.json — bỏ qua test live")
	}
	var resp struct {
		Solution struct {
			Response string `json:"response"`
		} `json:"solution"`
	}
	if err := json.Unmarshal(raw, &resp); err != nil {
		t.Fatalf("parse json lỗi: %v", err)
	}

	events, err := parseItems(resp.Solution.Response, "https://www.forexfactory.com/calendar?day=today")
	if err != nil {
		t.Fatalf("parseItems lỗi: %v", err)
	}
	t.Logf("Parse được %d sự kiện từ HTML thật", len(events))
	if len(events) == 0 {
		t.Fatal("không parse được sự kiện nào từ HTML thật — selector có thể sai")
	}
	for idx, e := range events {
		if idx >= 8 {
			break
		}
		t.Logf("  %-9s %-4s %-13s %-40s actual=%q forecast=%q previous=%q id=%s",
			e.Time, e.Currency, e.Impact, e.EventName, e.Actual, e.Forecast, e.Previous, e.EventID)
	}
}
