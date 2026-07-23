package main

import (
	"bytes"
	"compress/zlib"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
)

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

var users = make(map[int]User)
var payload = bytes.Repeat([]byte("x"), 10000)

func init() {
	for i := 1; i <= 1000; i++ {
		users[i] = User{ID: i, Name: fmt.Sprintf("User %d", i), Email: fmt.Sprintf("user%d@example.com", i)}
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func main() {
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"message": "Hello, World!"})
	})

	http.HandleFunc("/user/", func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Split(r.URL.Path, "/")
		if len(parts) < 3 {
			http.NotFound(w, r)
			return
		}
		id, err := strconv.Atoi(parts[2])
		if err != nil {
			http.NotFound(w, r)
			return
		}
		u, ok := users[id]
		if !ok {
			writeJSON(w, map[string]string{"error": "not found"})
			return
		}
		writeJSON(w, u)
	})

	http.HandleFunc("/cpu", func(w http.ResponseWriter, r *http.Request) {
		// Hashing
		h := sha256.Sum256(payload)
		// JSON processing
		type Item struct {
			ID  int     `json:"id"`
			Val float64 `json:"val"`
		}
		items := make([]Item, 100)
		for i := range items {
			items[i] = Item{ID: i, Val: rand.Float64()}
		}
		data := map[string]any{"items": items}
		b, _ := json.Marshal(data)
		var parsed map[string]any
		json.Unmarshal(b, &parsed)
		// Compression
		var buf bytes.Buffer
		zw := zlib.NewWriter(&buf)
		zw.Write(payload)
		zw.Close()

		writeJSON(w, map[string]any{
			"hash":            fmt.Sprintf("%x", h),
			"items":           100,
			"compressed_size": buf.Len(),
		})
	})

	fmt.Println("Go server running on port 3000")
	http.ListenAndServe(":3000", nil)
}
