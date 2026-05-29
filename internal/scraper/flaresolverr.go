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

func (f *FlareSolverr) post(ctx context.Context, body flareRequest) (*flareResponse, error) {
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.baseURL+"/v1", bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := f.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gọi FlareSolverr lỗi: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("FlareSolverr trả HTTP %d: %s", resp.StatusCode, truncate(string(data), 200))
	}

	var out flareResponse
	if err := json.Unmarshal(data, &out); err != nil {
		return nil, fmt.Errorf("không parse được phản hồi FlareSolverr: %w", err)
	}
	if out.Status != "ok" {
		return nil, fmt.Errorf("FlareSolverr báo lỗi: %s", out.Message)
	}
	return &out, nil
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
