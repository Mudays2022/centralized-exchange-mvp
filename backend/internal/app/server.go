package app

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/example/exchange/internal/matching"
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

type Server struct {
	cfg         *Config
	httpServer  *http.Server
	db          *sqlx.DB
	engine      *matching.Engine
	router      *gin.Engine
	broadcastHub *matching.Hub
}

func NewServer(cfg *Config) (*Server, error) {
	db, err := sqlx.Connect("postgres", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}

	// ensure WAL dir exists
	if err := os.MkdirAll(cfg.WALDir, 0o755); err != nil {
		return nil, err
	}
	walPath := filepath.Join(cfg.WALDir, cfg.WALFile)

	hub := matching.NewHub()
	engine := matching.NewEngine(walPath, hub, db)

	// replay WAL on startup to reconstruct state
	if err := engine.RecoverFromWAL(); err != nil {
		return nil, err
	}

	r := gin.Default()
	// enable CORS for frontend origins (adjust when deploying)
	UseCORS(r, []string{"http://localhost:5173", "https://your-vercel-domain.vercel.app"})
	api := r.Group("/api")
	registerRoutes(api, engine, db, hub)

	srv := &http.Server{
		Addr:    fmt.Sprintf("%s", cfg.Port),
		Handler: r,
	}

	return &Server{
		cfg:         cfg,
		httpServer:  srv,
		db:          db,
		engine:      engine,
		router:      r,
		broadcastHub: hub,
	}, nil
}

func (s *Server) Start() error {
	go s.broadcastHub.Run()
	return s.httpServer.ListenAndServe()
}

func (s *Server) Stop(ctx context.Context) error {
	// close engine WAL and DB
	s.engine.Close()
	s.broadcastHub.Close()
	_ = s.db.Close()
	return s.httpServer.Shutdown(ctx)
}