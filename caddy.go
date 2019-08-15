package main

import (
  "github.com/caddyserver/caddy/caddy/caddymain"

  _ "github.com/BTBurke/caddy-jwt"
  _ "github.com/tarent/loginsrv/caddy"
)

func main() {
  caddymain.EnableTelemetry = false
  caddymain.Run()
}
