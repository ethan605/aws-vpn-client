package samlserver

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
)

type samlServer struct {
	samlResponseCh chan string
	server         *http.Server
}

func NewServer() *samlServer {
	return &samlServer{
		samlResponseCh: make(chan string),
		server:         &http.Server{Addr: ":35001"},
	}
}

// Run spawns a new server at port 35001 listening to SAML response
func (s *samlServer) Run(shutdownCh <-chan bool) {
	http.HandleFunc("/", s.indexHandler)
	http.HandleFunc("/health", s.healthHandler)

	// Shutdown on signal
	go func() {
		<-shutdownCh

		if err := s.server.Shutdown(context.Background()); err != nil {
			log.Fatal("SAML server shutdown failed with error", err)
		}
	}()

	// Start up
	log.Printf("SAML server starting up at 127.0.0.1:35001")

	if err := s.server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatal("SAML server starting failed with error", err)
	}
}

func (s *samlServer) indexHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		if err := r.ParseForm(); err != nil {
			writeJSONResponse(w, fmt.Sprintf("ParseForm() err: %v", err), http.StatusUnprocessableEntity)
			return
		}

		samlResponse := r.FormValue("SAMLResponse")
		if len(samlResponse) == 0 {
			writeJSONResponse(w, "SAMLResponse field is empty or not exists", http.StatusUnprocessableEntity)
			return
		}

		s.samlResponseCh <- url.QueryEscape(samlResponse)
		fmt.Fprint(w, "Authentication details received, processing details. You may close this window at any time.")
		return
	default:
		writeJSONResponse(w, "POST method expected", http.StatusForbidden)
	}
}

func (s *samlServer) SAMLResponseCh() <-chan string {
	return s.samlResponseCh
}

func (s *samlServer) healthHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		writeJSONResponse(w, "ok", http.StatusOK)
		return
	default:
		writeJSONResponse(w, "GET method expected", http.StatusForbidden)
	}
}

func writeJSONResponse(w http.ResponseWriter, message string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	jsonResponse, _ := json.MarshalIndent(map[string]string{"message": message}, "", "  ")
	fmt.Fprint(w, string(jsonResponse))
}
