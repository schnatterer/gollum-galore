# Make sure wiki folder is always initialized, also on mounted volumes
(git init /gollum/wiki)&
# Set ENV only for caddy process. Makes it read the Caddyfile and store its other files in /app
(HOME=/app caddy $CADDY_PARAMS)&
# Start gollum in the foreground
exec gollum /gollum/wiki $GOLLUM_PARAMS
