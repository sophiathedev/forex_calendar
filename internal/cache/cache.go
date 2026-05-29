// Package cache là wrapper mỏng quanh go-cache, đóng vai trò như Cachex trong
// bản Elixir: lưu HTML đã cào, dữ liệu CPI, và state interaction theo TTL.
package cache

import (
	"time"

	gocache "github.com/patrickmn/go-cache"
)

// Các hằng TTL khớp với bản Elixir.
const (
	TTLEventHTML  = 10 * time.Minute // event<date>
	TTLDataPicker = 1 * time.Hour    // interaction:data:<id>
	TTLPagination = 30 * time.Minute // interaction:pagination:<id>
	NoExpiration  = gocache.NoExpiration
)

// Cache bọc *gocache.Cache để tập trung kiểu dữ liệu và TTL.
type Cache struct {
	c *gocache.Cache
}

// New tạo cache với TTL mặc định và chu kỳ dọn rác 10 phút.
func New() *Cache {
	return &Cache{c: gocache.New(10*time.Minute, 10*time.Minute)}
}

// Set lưu giá trị với TTL chỉ định (truyền NoExpiration để không hết hạn).
func (c *Cache) Set(key string, val any, ttl time.Duration) {
	c.c.Set(key, val, ttl)
}

// Get đọc giá trị; ok=false nếu không tồn tại hoặc đã hết hạn.
func (c *Cache) Get(key string) (any, bool) {
	return c.c.Get(key)
}

// GetString tiện ích đọc giá trị kiểu string.
func (c *Cache) GetString(key string) (string, bool) {
	v, ok := c.c.Get(key)
	if !ok {
		return "", false
	}
	s, ok := v.(string)
	return s, ok
}

// Delete xoá một key.
func (c *Cache) Delete(key string) {
	c.c.Delete(key)
}

// Exists kiểm tra key còn hiệu lực không.
func (c *Cache) Exists(key string) bool {
	_, ok := c.c.Get(key)
	return ok
}
