#!/bin/sh
set -o errexit -o nounset -o pipefail

GOLLUM_PARAMS=${GOLLUM_PARAMS:-"--config /app/config.rb"}

echo "Starting Gollum Galore $(cat /app/version)"

# Make sure wiki folder is always initialized, also on mounted volumes
(git init /gollum/wiki)&
# Set ENV only for caddy process. Makes it read the Caddyfile and store its other files in /app
echo "Starting Caddy with pararms \"${CADDY_PARAMS}\""
(HOME=/app caddy ${CADDY_PARAMS})&
echo "Starting Gollum with pararms \"${GOLLUM_PARAMS}\""
# Start gollum in the foreground
exec gollum /gollum/wiki ${GOLLUM_PARAMS}
