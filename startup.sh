# Make sure wiki folder is always initialized, also on mounted volumes
(git init /gollum/wiki)&
# Run traefik in the background
(traefik --file.filename=/app/traefik-routes.toml $TRAEFIK_PARAMS)
gollum /gollum/wiki $GOLLUM_PARAMS"
