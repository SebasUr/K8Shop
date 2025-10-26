package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

type healthResponse struct {
	OK bool `json:"ok"`
}

type recItem struct {
	ID    string  `json:"id"`
	Score float64 `json:"score"`
}

type recResponse struct {
	ProductID       string    `json:"productId,omitempty"`
	UserID          string    `json:"userId,omitempty"`
	Strategy        string    `json:"strategy"`
	Recommendations []recItem `json:"recommendations"`
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mustAtoi(s string, def int) int {
	if s == "" {
		return def
	}
	if n, err := strconv.Atoi(s); err == nil {
		return n
	}
	return def
}

func recommendationsHandler(w http.ResponseWriter, r *http.Request) {
	strategy := strings.ToLower(getenv("REC_STRATEGY", "popular"))
	if qStrategy := r.URL.Query().Get("strategy"); qStrategy != "" {
		strategy = strings.ToLower(qStrategy)
	}

	limit := mustAtoi(r.URL.Query().Get("limit"), mustAtoi(getenv("REC_LIMIT", "5"), 5))
	if limit < 1 {
		limit = 1
	}
	if limit > 50 {
		limit = 50
	}

	productID := r.URL.Query().Get("productId")
	userID := r.URL.Query().Get("userId")

	recs := make([]recItem, 0, limit)
	switch strategy {
	case "related":
		// Deterministic related recommendations based on productId seed
		seed := int64(42)
		if productID != "" {
			for _, b := range []byte(productID) {
				seed += int64(b)
			}
		}
		rng := rand.New(rand.NewSource(seed))
		for i := 0; i < limit; i++ {
			recs = append(recs, recItem{
				ID:    fmt.Sprintf("p%04d", rng.Intn(9999)),
				Score: 0.6 + rng.Float64()*0.4,
			})
		}
	default:
		// Popular strategy: pseudo-static list with stable randomness per day
		daySeed := time.Now().UTC().Format("2006-01-02")
		var seed int64 = 0
		for _, b := range []byte(daySeed) {
			seed += int64(b)
		}
		rng := rand.New(rand.NewSource(seed))
		for i := 0; i < limit; i++ {
			recs = append(recs, recItem{
				ID:    fmt.Sprintf("pop%03d", rng.Intn(1000)),
				Score: 0.5 + rng.Float64()*0.5,
			})
		}
		strategy = "popular"
	}

	resp := recResponse{
		ProductID:       productID,
		UserID:          userID,
		Strategy:        strategy,
		Recommendations: recs,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(healthResponse{OK: true})
}

func main() {
	// Load .env if present (no error if missing)
	_ = godotenv.Load()

	host := getenv("HOST", "127.0.0.1")
	port := getenv("PORT", "8080")

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthHandler)
	mux.HandleFunc("/recommendations", recommendationsHandler)

	srv := &http.Server{
		Addr:              host + ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("recommendation-service listening on %s:%s", host, port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}
