// Package scheduler thay thế Oban+Postgres bằng cron in-memory + registry job
// đã lên lịch (giữ trong RAM). Quản lý 3 job: ResetDaily, UpdateActivity, Cpi.
package scheduler

import (
	"context"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/bwmarrin/discordgo"
	"github.com/robfig/cron/v3"

	"forexbot/internal/cache"
	"forexbot/internal/embeds"
	"forexbot/internal/models"
	"forexbot/internal/scraper"
	"forexbot/internal/timeutil"
)

// scheduleThreshold: UpdateActivity chạy sau giờ ra tin 3 phút (giống bản Elixir).
const scheduleThreshold = 3 * time.Minute

// ScheduledJob là một lần chạy UpdateActivity đã được đặt lịch trong ngày.
type ScheduledJob struct {
	ID        int
	Timestamp string // nhãn giờ gốc, ví dụ "8:30am"
	FireAt    time.Time
	timer     *time.Timer
	fired     bool
}

// Scheduler điều phối cron và các job đã lên lịch.
type Scheduler struct {
	session   *discordgo.Session
	scraper   *scraper.Scraper
	cache     *cache.Cache
	channelID string

	cron *cron.Cron

	mu     sync.Mutex
	jobs   map[int]*ScheduledJob
	nextID int
}

// New tạo Scheduler.
func New(session *discordgo.Session, sc *scraper.Scraper, c *cache.Cache, channelID string) *Scheduler {
	return &Scheduler{
		session:   session,
		scraper:   sc,
		cache:     c,
		channelID: channelID,
		cron:      cron.New(cron.WithLocation(timeutil.VNLocation)),
		jobs:      make(map[int]*ScheduledJob),
	}
}

// Start đăng ký 2 cron job và khởi động cron (giống config :forex_bot, Oban crontab).
func (s *Scheduler) Start() error {
	if _, err := s.cron.AddFunc("1 0 * * *", func() { s.RunResetDaily() }); err != nil {
		return err
	}
	if _, err := s.cron.AddFunc("1 0 1 * *", func() { s.RunCpi() }); err != nil {
		return err
	}
	s.cron.Start()
	return nil
}

// Stop dừng cron và mọi timer đã lên lịch.
func (s *Scheduler) Stop() {
	s.cron.Stop()
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, j := range s.jobs {
		if j.timer != nil {
			j.timer.Stop()
		}
	}
}

func jobCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 2*time.Minute)
}

// RunResetDaily: xoá tin cũ trong channel, đăng lịch tin trong ngày, rồi lên lịch
// UpdateActivity cho từng mốc giờ có tin. Tương đương ForexBot.Jobs.ResetDaily.
func (s *Scheduler) RunResetDaily() {
	log.Println("[ResetDaily] bắt đầu")
	ctx, cancel := jobCtx()
	defer cancel()

	s.bulkDeleteMessages()

	events, err := s.scraper.ParseTodayEvents(ctx, true)
	if err != nil {
		log.Printf("[ResetDaily] cào lỗi, giữ nguyên trạng thái: %v", err)
		return
	}
	important := models.FilterImportant(events)

	chunks := models.Chunk(important, 15)
	emb := make([]*discordgo.MessageEmbed, 0, len(chunks))
	for _, ch := range chunks {
		emb = append(emb, embeds.TodayEmbed(ch))
	}
	if len(emb) == 0 {
		emb = append(emb, embeds.TodayEmbed(nil))
	}

	msg, err := s.session.ChannelMessageSendComplex(s.channelID, &discordgo.MessageSend{Embeds: emb})
	if err != nil {
		log.Printf("[ResetDaily] gửi message lỗi: %v", err)
		return
	}
	s.cache.Set("reset_daily_message:"+s.channelID, msg.ID, cache.NoExpiration)

	// Ngày mới: xoá lịch cũ rồi lên lịch lại theo từng mốc giờ duy nhất.
	s.clearJobs()
	for _, ts := range uniqueTimestamps(important) {
		s.scheduleActivity(ts)
	}
	log.Printf("[ResetDaily] xong, %d tin quan trọng", len(important))
}

// scheduleActivity đặt một timer chạy UpdateActivity tại (giờ tin + 3 phút) nếu còn ở tương lai.
func (s *Scheduler) scheduleActivity(timestamp string) {
	h, m, ok := models.ConvertTime24h(timestamp)
	if !ok {
		return // "All Day", "Tentative", ... không lên lịch được
	}
	now := timeutil.NowVN()
	fireAt := time.Date(now.Year(), now.Month(), now.Day(), h, m, 0, 0, timeutil.VNLocation).Add(scheduleThreshold)
	if !fireAt.After(now) {
		log.Printf("[ResetDaily] bỏ qua mốc %s (đã quá khứ)", timestamp)
		return
	}

	s.mu.Lock()
	s.nextID++
	id := s.nextID
	job := &ScheduledJob{ID: id, Timestamp: timestamp, FireAt: fireAt}
	job.timer = time.AfterFunc(fireAt.Sub(now), func() { s.fireJob(id) })
	s.jobs[id] = job
	s.mu.Unlock()

	log.Printf("[ResetDaily] đã lên lịch UpdateActivity cho %s lúc %s (job #%d)", timestamp, fireAt.Format("15:04"), id)
}

// fireJob đánh dấu job đã chạy rồi thực thi UpdateActivity.
func (s *Scheduler) fireJob(id int) {
	s.mu.Lock()
	job, ok := s.jobs[id]
	if !ok || job.fired {
		s.mu.Unlock()
		return
	}
	job.fired = true
	ts := job.Timestamp
	s.mu.Unlock()

	s.RunUpdateActivity(ts)
}

// RunUpdateActivity: cập nhật message lịch chính và đăng tin mới của một mốc giờ.
// Tương đương ForexBot.Jobs.UpdateActivity.
func (s *Scheduler) RunUpdateActivity(timestamp string) {
	log.Printf("[UpdateActivity] chạy cho mốc %s", timestamp)
	ctx, cancel := jobCtx()
	defer cancel()

	// Xoá message activity cũ (nếu có).
	if oldID, ok := s.cache.GetString("activity_message:" + s.channelID); ok && oldID != "" {
		_ = s.session.ChannelMessageDelete(s.channelID, oldID)
	}

	events, err := s.scraper.ParseTodayEvents(ctx, false) // no-cache: lấy actual mới nhất
	if err != nil {
		log.Printf("[UpdateActivity] cào lỗi, bỏ qua lần này: %v", err)
		return
	}
	important := models.FilterImportant(events)

	// Cập nhật message lịch chính với toàn bộ tin trong ngày.
	s.updateMainMessage(important)

	// Lọc tin của đúng mốc giờ này.
	var matched []models.Event
	for _, e := range important {
		if e.Time == timestamp {
			matched = append(matched, e)
		}
	}

	chunks := models.Chunk(matched, 15)
	emb := make([]*discordgo.MessageEmbed, 0, len(chunks))
	for _, ch := range chunks {
		emb = append(emb, embeds.ActivityEmbed(ch))
	}
	if len(emb) == 0 {
		emb = append(emb, embeds.ActivityEmbed(nil))
	}

	msg, err := s.session.ChannelMessageSendComplex(s.channelID, &discordgo.MessageSend{Embeds: emb})
	if err != nil {
		log.Printf("[UpdateActivity] gửi message lỗi: %v", err)
		return
	}
	s.cache.Set("activity_message:"+s.channelID, msg.ID, cache.NoExpiration)
}

// updateMainMessage edit lại message lịch chính (do ResetDaily tạo).
func (s *Scheduler) updateMainMessage(events []models.Event) {
	mainID, ok := s.cache.GetString("reset_daily_message:" + s.channelID)
	if !ok || mainID == "" {
		return
	}
	chunks := models.Chunk(events, 15)
	emb := make([]*discordgo.MessageEmbed, 0, len(chunks))
	for _, ch := range chunks {
		emb = append(emb, embeds.TodayEmbed(ch))
	}
	if len(emb) == 0 {
		emb = append(emb, embeds.TodayEmbed(nil))
	}
	_, err := s.session.ChannelMessageEditComplex(&discordgo.MessageEdit{
		Channel: s.channelID,
		ID:      mainID,
		Embeds:  &emb,
	})
	if err != nil {
		log.Printf("[UpdateActivity] edit message chính lỗi: %v", err)
	}
}

// RunCpi: cào 13 mốc tháng gần nhất, lọc, lưu cpi_data. Tương đương ForexBot.Jobs.Cpi.
func (s *Scheduler) RunCpi() {
	log.Println("[Cpi] bắt đầu cào dữ liệu lịch sử")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	now := timeutil.NowVN()
	curMonth := int(now.Month())
	curYear := now.Year()

	var all []models.Event
	for v := curMonth - 12; v <= curMonth; v++ {
		month := v
		year := curYear
		if v <= 0 {
			month = 12 + v
			year = curYear - 1
		}
		evts, err := s.scraper.ParseMonth(ctx, month, year)
		if err != nil {
			log.Printf("[Cpi] tháng %d/%d lỗi (bỏ qua): %v", month, year, err)
			continue
		}
		all = append(all, models.FilterImportantNamed(evts)...)
	}

	if len(all) == 0 {
		log.Println("[Cpi] không lấy được dữ liệu nào — giữ cache cũ")
		return
	}
	s.cache.Set("cpi_data", all, cache.NoExpiration)
	log.Printf("[Cpi] xong, %d sự kiện quan trọng trong 12 tháng", len(all))
}

// PendingJobs trả các job UpdateActivity còn chờ trong ngày (cho /announce).
func (s *Scheduler) PendingJobs() []ScheduledJob {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []ScheduledJob
	for _, j := range s.jobs {
		if !j.fired {
			out = append(out, *j)
		}
	}
	sort.Slice(out, func(i, k int) bool { return out[i].FireAt.Before(out[k].FireAt) })
	return out
}

// TriggerNow chạy ngay một job đã lên lịch (cho nút "announce ngay"). Chạy nền.
func (s *Scheduler) TriggerNow(id int) bool {
	s.mu.Lock()
	job, ok := s.jobs[id]
	if !ok || job.fired {
		s.mu.Unlock()
		return false
	}
	job.fired = true
	if job.timer != nil {
		job.timer.Stop()
	}
	ts := job.Timestamp
	s.mu.Unlock()

	go s.RunUpdateActivity(ts)
	return true
}

func (s *Scheduler) clearJobs() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, j := range s.jobs {
		if j.timer != nil {
			j.timer.Stop()
		}
	}
	s.jobs = make(map[int]*ScheduledJob)
}

// bulkDeleteMessages xoá tối đa 100 message gần nhất trong channel.
func (s *Scheduler) bulkDeleteMessages() {
	msgs, err := s.session.ChannelMessages(s.channelID, 100, "", "", "")
	if err != nil {
		log.Printf("[ResetDaily] lấy message để xoá lỗi: %v", err)
		return
	}
	if len(msgs) == 0 {
		return
	}
	ids := make([]string, 0, len(msgs))
	for _, m := range msgs {
		ids = append(ids, m.ID)
	}
	if len(ids) == 1 {
		_ = s.session.ChannelMessageDelete(s.channelID, ids[0])
		return
	}
	if err := s.session.ChannelMessagesBulkDelete(s.channelID, ids); err != nil {
		log.Printf("[ResetDaily] bulk delete lỗi: %v", err)
	}
}

func uniqueTimestamps(events []models.Event) []string {
	seen := make(map[string]bool)
	var out []string
	for _, e := range events {
		if e.Time != "" && !seen[e.Time] {
			seen[e.Time] = true
			out = append(out, e.Time)
		}
	}
	return out
}
