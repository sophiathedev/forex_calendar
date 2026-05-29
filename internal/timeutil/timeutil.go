// Package timeutil tập trung các tiện ích thời gian theo múi giờ Việt Nam.
// Tương đương ForexBot.Utils trong bản Elixir.
package timeutil

import "time"

// VNLocation là múi giờ Asia/Ho_Chi_Minh dùng xuyên suốt bot.
// Nạp một lần lúc khởi tạo package; nếu hệ thống thiếu tzdata sẽ panic ngay
// để lỗi lộ ra sớm thay vì tính giờ sai âm thầm.
var VNLocation = mustLoadVN()

func mustLoadVN() *time.Location {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		panic("không nạp được múi giờ Asia/Ho_Chi_Minh: " + err.Error())
	}
	return loc
}

// NowVN trả về thời điểm hiện tại theo giờ Việt Nam (ForexBot.Utils.localtime_now/0).
func NowVN() time.Time {
	return time.Now().In(VNLocation)
}

// TodayID trả về khoá ngày dạng "YYYYMMDD" theo giờ VN (ForexBot.Utils.today_id/0),
// dùng làm key cache cho HTML lịch tin trong ngày.
func TodayID() string {
	return NowVN().Format("20060102")
}
