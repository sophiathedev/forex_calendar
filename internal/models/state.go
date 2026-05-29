package models

// DataState là trạng thái của luồng /data nhiều bước (month → event → currency),
// lưu trong cache theo id của interaction lệnh gốc. Tách khỏi discordgo để
// commands và interactions cùng dùng mà không tạo import cycle.
type DataState struct {
	Month     int
	EventName string
	Currency  string
}
