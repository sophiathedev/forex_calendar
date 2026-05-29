# ForexBot (Go)

Discord bot cào lịch tin kinh tế từ ForexFactory, tự động đăng tin theo ngày/theo
giờ vào một channel, và cung cấp 4 slash command tra cứu bằng tiếng Việt. Đây là
bản viết lại bằng Go của bot Elixir gốc (`../forex_bot`).

## Kiến trúc

- **discordgo** — kết nối Discord gateway, slash command, component (button/select).
- **FlareSolverr** — service riêng chạy headless browser để **vượt Cloudflare**
  (ForexFactory trả 403 với HTTP thường). Bot chỉ gọi HTTP tới nó rồi parse HTML
  bằng **goquery**.
- **robfig/cron** + **time.Timer** — thay Oban: 2 cron job (ResetDaily 00:01 mỗi
  ngày, Cpi đầu tháng) + registry job in-memory cho các mốc "tin mới gần đây".
- **go-cache** — thay Cachex: cache HTML, dữ liệu CPI 12 tháng, state interaction.
- **Không dùng database** — toàn bộ state nằm in-memory (bản gốc Postgres chỉ phục vụ Oban).

```
cmd/bot/main.go              # khởi tạo & wiring
internal/
  config/                    # đọc env (.env)
  timeutil/                  # giờ Asia/Ho_Chi_Minh
  models/                    # Event, whitelist sự kiện, ConvertTime24h, Chunk
  cache/                     # wrapper go-cache
  scraper/                   # flaresolverr.go (client) + forexfactory.go (parse)
  embeds/                    # builder embed/button/select dùng chung
  discord/                   # session, đăng ký lệnh (bot.go), router (router.go)
  commands/                  # /today /data /announce /help
  interactions/              # luồng /data nhiều bước, phân trang, announce-ngay
  scheduler/                 # cron + job ResetDaily/UpdateActivity/Cpi
```

## Slash command

| Lệnh | Mô tả |
|------|-------|
| `/today` | Lịch tin trong ngày |
| `/data month:<1-12>` | Dữ liệu lịch sử: chọn loại sự kiện → tiền tệ → xem (có phân trang) |
| `/announce` | Chọn một mốc tin đã lên lịch để thông báo ngay |
| `/help` | Hướng dẫn |

## Chạy

Cần biến môi trường: `DISCORD_TOKEN`, `GUILD_ID`, `CHANNEL_ID`, `FLARESOLVERR_URL`
(xem [.env.example](.env.example)).

### Docker (khuyến nghị — kèm FlareSolverr)

```bash
cp .env.example .env   # điền token/guild/channel
docker compose up -d
```

### Local

```bash
docker compose up -d flaresolverr      # cần FlareSolverr chạy
cp .env.example .env                   # FLARESOLVERR_URL=http://localhost:8191
go run ./cmd/bot
```

## Kiểm thử

```bash
go test ./...      # unit test parser + models (không cần mạng)
go vet ./...
```

Kiểm tra FlareSolverr vượt được Cloudflare:

```bash
curl -s -X POST http://localhost:8191/v1 \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://www.forexfactory.com/calendar?day=today","maxTimeout":60000}' \
  | grep -o '"status":[0-9]*' | head -1   # mong đợi 200
```
