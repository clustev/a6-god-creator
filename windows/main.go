package main

import (
	"crypto/rand"
	"embed"
	"encoding/hex"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

//go:embed web/*
var files embed.FS

func main() {
	assets, err := fs.Sub(files, "web")
	if err != nil {
		log.Fatal(err)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatalf("Cannot start local editor: %v", err)
	}
	defer listener.Close()
	secret := make([]byte, 16)
	if _, err := rand.Read(secret); err != nil {
		log.Fatal(err)
	}
	prefix := "/" + hex.EncodeToString(secret) + "/"
	host := listener.Addr().String()
	url := "http://" + host + prefix
	content := http.StripPrefix(prefix, http.FileServer(http.FS(assets)))
	mux := http.NewServeMux()
	mux.Handle(prefix, content)
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Host != host {
			http.Error(w, "Invalid host", http.StatusForbidden)
			return
		}
		w.Header().Set("Content-Security-Policy", "default-src 'self'; img-src 'self' data: blob:; style-src 'self'; script-src 'self'; base-uri 'none'; frame-ancestors 'none'")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "no-store")
		mux.ServeHTTP(w, r)
	})
	server := &http.Server{Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	fmt.Println("Card Maker is running locally. Keep this window open.")
	fmt.Println("Close this window to stop the app.")
	fmt.Println(url)
	if os.Getenv("CARDMAKER_NO_BROWSER") == "" {
		go func() {
			var command *exec.Cmd
			if runtime.GOOS == "windows" {
				for _, env := range []string{"ProgramFiles(x86)", "ProgramFiles", "LOCALAPPDATA"} {
					if root := os.Getenv(env); root != "" {
						path := filepath.Join(root, "Microsoft", "Edge", "Application", "msedge.exe")
						if info, e := os.Stat(path); e == nil && !info.IsDir() {
							command = exec.Command(path, url)
							break
						}
					}
				}
				if command == nil {
					command = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
				}
			} else if runtime.GOOS == "darwin" {
				command = exec.Command("open", url)
			} else {
				command = exec.Command("xdg-open", url)
			}
			if err := command.Start(); err != nil {
				fmt.Fprintln(os.Stderr, "Open the address above in your browser:", err)
			}
		}()
	}
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
