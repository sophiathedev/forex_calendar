package models

import "testing"

func TestConvertTime24h(t *testing.T) {
	cases := []struct {
		in   string
		h, m int
		ok   bool
	}{
		{"8:30am", 8, 30, true},
		{"12:00am", 0, 0, true},   // nửa đêm
		{"12:30pm", 12, 30, true}, // giữa trưa
		{"1:00pm", 13, 0, true},
		{"11:45pm", 23, 45, true},
		{"All Day", -1, -1, false},
		{"Tentative", -1, -1, false},
		{"", -1, -1, false},
	}
	for _, c := range cases {
		h, m, ok := ConvertTime24h(c.in)
		if h != c.h || m != c.m || ok != c.ok {
			t.Errorf("ConvertTime24h(%q) = (%d,%d,%v), mong đợi (%d,%d,%v)", c.in, h, m, ok, c.h, c.m, c.ok)
		}
	}
}

func TestChunk(t *testing.T) {
	events := make([]Event, 5)
	chunks := Chunk(events, 2)
	if len(chunks) != 3 {
		t.Fatalf("mong đợi 3 nhóm, nhận %d", len(chunks))
	}
	if len(chunks[0]) != 2 || len(chunks[1]) != 2 || len(chunks[2]) != 1 {
		t.Errorf("kích thước nhóm sai: %d,%d,%d", len(chunks[0]), len(chunks[1]), len(chunks[2]))
	}
}

func TestFilterImportantNamed(t *testing.T) {
	events := []Event{
		{Currency: "USD", Impact: "High", EventName: "CPI m/m"},      // giữ
		{Currency: "USD", Impact: "High", EventName: "Random Event"}, // loại: tên không trong whitelist
		{Currency: "AUD", Impact: "High", EventName: "CPI m/m"},      // loại: tiền tệ
		{Currency: "USD", Impact: "Low", EventName: "CPI m/m"},       // loại: impact
	}
	got := FilterImportantNamed(events)
	if len(got) != 1 || got[0].EventName != "CPI m/m" || got[0].Currency != "USD" {
		t.Errorf("FilterImportantNamed sai: %+v", got)
	}
}
