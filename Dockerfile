# ---- build ----
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/bot ./cmd/bot

# ---- runtime ----
FROM alpine:3.20
# tzdata cho Asia/Ho_Chi_Minh; ca-certificates cho HTTPS tới Discord/FlareSolverr.
RUN apk add --no-cache tzdata ca-certificates
ENV TZ=Asia/Ho_Chi_Minh
COPY --from=build /out/bot /usr/local/bin/bot
ENTRYPOINT ["/usr/local/bin/bot"]
