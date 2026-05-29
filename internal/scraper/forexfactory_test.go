package scraper

import "testing"

// HTML mẫu mô phỏng cấu trúc bảng lịch ForexFactory: 2 dòng, dòng thứ 2 thiếu
// giờ và ngày để kiểm tra forward-fill.
const sampleHTML = `
<table class="calendar__table">
  <tr class="calendar__row" data-event-id="123">
    <td class="calendar__date">Mon May 26</td>
    <td class="calendar__time">8:30am</td>
    <td class="calendar__currency">USD</td>
    <td class="calendar__impact"><span class="icon icon--ff-impact-red"></span></td>
    <td class="calendar__event"><span class="calendar__event-title">Core CPI m/m</span></td>
    <td class="calendar__actual">0.3%</td>
    <td class="calendar__forecast">0.2%</td>
    <td class="calendar__previous">0.1%</td>
  </tr>
  <tr class="calendar__row" data-event-id="124">
    <td class="calendar__date"></td>
    <td class="calendar__time"></td>
    <td class="calendar__currency">EUR</td>
    <td class="calendar__impact"><span class="icon icon--ff-impact-ora"></span></td>
    <td class="calendar__event"><span class="calendar__event-title">CPI y/y</span></td>
    <td class="calendar__actual"></td>
    <td class="calendar__forecast">1.0%</td>
    <td class="calendar__previous">0.9%</td>
  </tr>
  <tr class="calendar__row">
    <td class="calendar__date"></td>
    <td class="calendar__time"></td>
    <td class="calendar__currency"></td>
    <td class="calendar__impact"></td>
    <td class="calendar__event"><span class="calendar__event-title"></span></td>
    <td class="calendar__actual"></td>
    <td class="calendar__forecast"></td>
    <td class="calendar__previous"></td>
  </tr>
</table>`

func TestParseItems(t *testing.T) {
	events, err := parseItems(sampleHTML, "https://www.forexfactory.com/calendar?day=today")
	if err != nil {
		t.Fatalf("parseItems lỗi: %v", err)
	}
	// Dòng 3 không có event title -> bị loại; còn 2 sự kiện.
	if len(events) != 2 {
		t.Fatalf("mong đợi 2 sự kiện, nhận %d", len(events))
	}

	e0 := events[0]
	if e0.Time != "8:30am" || e0.Currency != "USD" || e0.Impact != "High" {
		t.Errorf("dòng 0 sai: %+v", e0.Event)
	}
	if e0.EventName != "Core CPI m/m" || e0.Actual != "0.3%" {
		t.Errorf("dòng 0 tên/actual sai: %+v", e0.Event)
	}
	if e0.EventID != "123" || e0.EventURL != "https://www.forexfactory.com/calendar?day=today#detail=123" {
		t.Errorf("dòng 0 event id/url sai: %+v", e0.Event)
	}
	if e0.dayOfMonth != 26 {
		t.Errorf("dòng 0 ngày sai: %d", e0.dayOfMonth)
	}

	e1 := events[1]
	if e1.Impact != "Medium" {
		t.Errorf("dòng 1 impact sai: %q", e1.Impact)
	}
	// Forward-fill: dòng 1 thiếu giờ/ngày -> kế thừa dòng 0.
	if e1.Time != "8:30am" {
		t.Errorf("forward-fill giờ sai: %q", e1.Time)
	}
	if e1.dayOfMonth != 26 {
		t.Errorf("forward-fill ngày sai: %d", e1.dayOfMonth)
	}
}
