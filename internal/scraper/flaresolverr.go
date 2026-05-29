// Package scraper lo việc lấy và parse lịch tin ForexFactory.
//
// ForexFactory đứng sau Cloudflare: GET HTTP thường (kể cả UA trình duyệt) trả
// 403. Vì vậy mọi request HTML đi qua FlareSolverr — một service riêng chạy
// headless browser để giải JS challenge rồi trả HTML đã render. Bot Go chỉ nói
// chuyện HTTP với nó (không nhúng Chrome).
package scraper

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// FlareSolverr là client tới một instance FlareSolverr.
type FlareSolverr struct {
	baseURL   string
	http      *http.Client
	sessionID string // id session để tái dùng (giữ browser ấm + cookie)
}

// NewFlareSolverr tạo client. maxTimeout của FlareSolverr là 60s nên HTTP client
// để rộng hơn (90s) để bao trọn thời gian giải challenge.
func NewFlareSolverr(baseURL string) *FlareSolverr {
	return &FlareSolverr{
		baseURL: strings.TrimRight(baseURL, "/"),
		http:    &http.Client{Timeout: 90 * time.Second},
	}
}

// flareRequest là body gửi tới POST /v1.
type flareRequest struct {
	Cmd        string `json:"cmd"`
	URL        string `json:"url,omitempty"`
	Session    string `json:"session,omitempty"`
	MaxTimeout int    `json:"maxTimeout,omitempty"`
}

// flareResponse là phần phản hồi ta quan tâm.
type flareResponse struct {
	Status   string `json:"status"`
	Message  string `json:"message"`
	Session  string `json:"session"`
	Solution struct {
		URL      string `json:"url"`
		Status   int    `json:"status"`
		Response string `json:"response"`
	} `json:"solution"`
}

// postRetries là số lần thử lại cho lỗi mạng tạm thời (vd FlareSolverr đang
// khởi động/restart → connection refused).
const postRetries = 3

// post gọi /v1 với retry cho lỗi tạm thời. Lỗi cấp ứng dụng (FlareSolverr trả
// status "error") không retry vì thử lại ngay cũng không giúp.
func (f *FlareSolverr) post(ctx context.Context, body flareRequest) (*flareResponse, error) {
	var lastErr error
	for attempt := 1; attempt <= postRetries; attempt++ {
		out, transient, err := f.postOnce(ctx, body)
		if err == nil {
			return out, nil
		}
		lastErr = err
		if !transient {
			return nil, err
		}
		// backoff tuyến tính: 2s, 4s, ...
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Duration(attempt) * 2 * time.Second):
		}
	}
	return nil, lastErr
}

// postOnce thực hiện một request. transient=true nghĩa là lỗi mạng/server tạm
// thời, nên thử lại.
func (f *FlareSolverr) postOnce(ctx context.Context, body flareRequest) (resp *flareResponse, transient bool, err error) {
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, false, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.baseURL+"/v1", bytes.NewReader(buf))
	if err != nil {
		return nil, false, err
	}
	req.Header.Set("Content-Type", "application/json")

	httpResp, err := f.http.Do(req)
	if err != nil {
		return nil, true, fmt.Errorf("gọi FlareSolverr lỗi: %w", err) // lỗi mạng -> thử lại
	}
	defer httpResp.Body.Close()

	data, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return nil, true, err
	}
	if httpResp.StatusCode != http.StatusOK {
		// 5xx/khác từ chính server FlareSolverr -> coi là tạm thời.
		return nil, httpResp.StatusCode >= 500, fmt.Errorf("FlareSolverr trả HTTP %d: %s", httpResp.StatusCode, truncate(string(data), 200))
	}

	var out flareResponse
	if err := json.Unmarshal(data, &out); err != nil {
		return nil, false, fmt.Errorf("không parse được phản hồi FlareSolverr: %w", err)
	}
	if out.Status != "ok" {
		return nil, false, fmt.Errorf("FlareSolverr báo lỗi: %s", out.Message)
	}
	return &out, false, nil
}

// WaitReady chờ FlareSolverr phản hồi HTTP (đã sẵn sàng) hoặc tới khi ctx hết hạn.
// Dùng lúc khởi động để tránh race với việc FlareSolverr còn đang boot Chromium.
func (f *FlareSolverr) WaitReady(ctx context.Context) error {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		probeCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		req, _ := http.NewRequestWithContext(probeCtx, http.MethodGet, f.baseURL+"/", nil)
		resp, err := f.http.Do(req)
		cancel()
		if err == nil {
			resp.Body.Close()
			return nil
		}
		select {
		case <-ctx.Done():
			return fmt.Errorf("FlareSolverr chưa sẵn sàng: %w", ctx.Err())
		case <-ticker.C:
		}
	}
}

// CreateSession tạo một session để tái dùng cho các request sau.
// Gọi một lần lúc khởi động; nếu lỗi vẫn dùng được (mỗi Get sẽ chạy không session).
func (f *FlareSolverr) CreateSession(ctx context.Context) error {
	out, err := f.post(ctx, flareRequest{Cmd: "sessions.create"})
	if err != nil {
		return err
	}
	f.sessionID = out.Session
	return nil
}

// DestroySession huỷ session (gọi lúc shutdown).
func (f *FlareSolverr) DestroySession(ctx context.Context) {
	if f.sessionID == "" {
		return
	}
	_, _ = f.post(ctx, flareRequest{Cmd: "sessions.destroy", Session: f.sessionID})
	f.sessionID = ""
}

// Get lấy HTML đã vượt Cloudflare của một URL. Trả lỗi rõ ràng (không trả HTML
// rỗng) khi: gọi lỗi, solution.status != 200, hoặc HTML vẫn còn dấu hiệu challenge.
func (f *FlareSolverr) Get(ctx context.Context, url string) (string, error) {
	out, err := f.post(ctx, flareRequest{
		Cmd:        "request.get",
		URL:        url,
		Session:    f.sessionID,
		MaxTimeout: 60000,
	})
	if err != nil {
		return "", err
	}
	if out.Solution.Status != http.StatusOK {
		return "", fmt.Errorf("trang trả HTTP %d (có thể bị Cloudflare chặn): %s", out.Solution.Status, url)
	}
	html := out.Solution.Response
	if looksLikeChallenge(html) {
		return "", fmt.Errorf("vẫn dính challenge Cloudflare cho %s", url)
	}
	return html, nil
}

// looksLikeChallenge nhận diện trang challenge của Cloudflare còn sót lại.
func looksLikeChallenge(html string) bool {
	low := strings.ToLower(html)
	return strings.Contains(low, "just a moment") ||
		strings.Contains(low, "cf-challenge") ||
		strings.Contains(low, "challenge-platform") ||
		strings.Contains(low, "attention required")
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
