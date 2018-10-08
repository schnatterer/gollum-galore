# Build caddy from source, because binaries are published under a commercial license: https://caddyserver.com/pricing
FROM golang:1.10.0 as caddybuild
ARG CADDY_VERSION="0.10.10"
RUN \
  git clone https://github.com/mholt/caddy /go/src/github.com/mholt/caddy \
  && cd /go/src/github.com/mholt/caddy \
  && git checkout -b "v$CADDY_VERSION" \
  # Build Plugins http.login and http.jwt
  #&& sed -e 's/\(\s\)"github.com\/mholt\/caddy\/caddyfile"/\1"github.com\/mholt\/caddy\/caddyfile"\n\1"github.com\/BTBurke\/caddy-jwt"\n\1"github.com\/tarent\/loginsrv/'
  && printf " \
  package caddyhttp \n\
  import (  \n\
    // http.jwt  \n\
    _ \"github.com/BTBurke/caddy-jwt\"  \n\
    // http.login  \n\
    _ \"github.com/tarent/loginsrv/caddy\" \n\
  )" > /go/src/github.com/mholt/caddy/caddyhttp/plugins.go \
  && go get -d -v github.com/caddyserver/builds \
  && cd /go/src/github.com/mholt/caddy/caddy \
  && go get ./... \
  && go run build.go \
  && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o caddy .

# Build gollum galore
FROM ruby:2.4.1-alpine

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g '--config /config/gollum.ru', in addition to -v /FOLDER/ON/HOST:/gollum/config
ENV GOLLUM_PARAMS=''
# e.g '-conf /gollum/config/Caddyfile', in addition to -v /FOLDER/ON/HOST:/gollum/config
ENV CADDY_PARAMS=''
ENV HOST=':80'

# As we need to start two processes, copy a startup script that starts only one process in the foreground  :-/
# BTW you can customize 'gollum's' git user using the following command in the (mounted) /gollum/wiki folder:
#  git config user.name 'John Doe' && git config user.email 'john@doe.org'
COPY startup.sh /startup.sh
COPY --from=caddybuild /go/src/github.com/mholt/caddy/caddy/caddy /usr/local/bin/

RUN \
  apk --update add \
  # Need for gem install TODO move to docker.build?
  alpine-sdk icu-dev \
  # Needed for running gollum
  git \
  # Useful for backup
  rsync openssh \
  # Install gollum
  && gem install gollum  \
  # cleanup apk cache
  && rm -rf /var/cache/apk/* \
  # Initialize wiki data.
  # Can be made persistent via -v /FOLDER/ON/HOST:/gollum/wikidata.
  && mkdir -p /gollum/wiki && mkdir -p /gollum/config \
  # Create caddyfile that can be mounted when running
  && touch /gollum/config/Caddyfile \
  # Create base folder for startup script.
  && mkdir /app \
  # Make dirs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod a+rw /app \
  && chmod -R a+rw /gollum/ \
  # Allow caddy to bind to port 80 as non-root
  && setcap cap_net_bind_service=+ep $(which caddy) \
  && chmod +rx /startup.sh

COPY Caddyfile /app
WORKDIR  app

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start caddy and gollum
CMD /startup.sh
