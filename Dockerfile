# Build caddy from source, because binaries are published under a commercial license: https://caddyserver.com/pricing
FROM golang:1.10.0 as caddybuild
ARG CADDY_VERSION="0.10.14"
RUN \
  git clone https://github.com/mholt/caddy /go/src/github.com/mholt/caddy \
  && cd /go/src/github.com/mholt/caddy \
  && git checkout tags/"v$CADDY_VERSION" -b "v$CADDY_VERSION" \
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
# As of 10/2018 ruby 2.3 seems the be te latest ruby version provided with The latest alpine 3.8
FROM ruby:2.3.7-alpine3.8

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

ENV GOLLUM_VERSION="4.1.3"

# https://pkgs.alpinelinux.org/packages?name=git&branch=v3.8
ENV GIT_VERSION=2.18.0-r0
# https://pkgs.alpinelinux.org/packages?name=rsync&branch=v3.8
ENV RSYNC_VERSION=3.1.3-r1
# https://pkgs.alpinelinux.org/packages?name=openssh&branch=v3.8
ENV OPENSSH_VERSION=7.7_p1-r3

# https://pkgs.alpinelinux.org/packages?name=openssh&branch=v3.8
ENV ALPINE_SDK_VERSION=1.0-r0
#https://pkgs.alpinelinux.org/packages?name=icu-dev&branch=v3.8
ENV ICU_DEV_VERSION=60.2-r2

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
  alpine-sdk=$ALPINE_SDK_VERSION icu-dev=$ICU_DEV_VERSION \
  # Needed for running gollum
  git=$GIT_VERSION \
  # Useful for backup
  rsync=$RSYNC_VERSION openssh=$OPENSSH_VERSION \
  # Install gollum
  && gem install gollum -v $GOLLUM_VERSION \
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
