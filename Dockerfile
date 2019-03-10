# Build caddy from source, because binaries are published under a commercial license: https://caddyserver.com/pricing
FROM golang:1.12.0 as caddybuild
ARG CADDY_VERSION="v0.11.5"
RUN git clone https://github.com/mholt/caddy /go/src/github.com/mholt/caddy
WORKDIR  /go/src/github.com/mholt/caddy
RUN git checkout tags/"$CADDY_VERSION" -b "$CADDY_VERSION"
# Include Plugins http.login and http.jwt
RUN sed -ie 's/\/\/ This is where other plugins get plugged in (imported)/_ "github.com\/BTBurke\/caddy-jwt"\n        _ "github.com\/tarent\/loginsrv\/caddy"/' \
   /go/src/github.com/mholt/caddy/caddy/caddymain/run.go
RUN go get -d -v github.com/caddyserver/builds
WORKDIR /go/src/github.com/mholt/caddy/caddy
RUN go get ./...
RUN go run build.go

# Prepare file structure for final image
RUN mkdir -p /dist/app && mkdir -p /dist/usr/local/bin
RUN cp /go/src/github.com/mholt/caddy/caddy/caddy /dist/usr/local/bin/
# As we need to start two processes, copy a startup script that starts only one process in the foreground  :-/
# BTW you can customize 'gollum's' git user using the following command in the (mounted) /gollum/wiki folder:
#  git config user.name 'John Doe' && git config user.email 'john@doe.org'
COPY startup.sh /dist/startup.sh
COPY Caddyfile /dist/app/

# Build gollum galore
FROM ruby:2.6.1-alpine3.9

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# - Sources:
#   - https://pkgs.alpinelinux.org/packages?name=git&branch=v3.9
# - GOLLUM_PARAMS. Additional gollom config: See https://github.com/gollum/gollum#configuration
#    e.g '--config /config/gollum.ru', in addition to -v /FOLDER/ON/HOST:/gollum/config
# - CADDY_PARAMS e.g '-conf /gollum/config/Caddyfile', in addition to -v /FOLDER/ON/HOST:/gollum/config
# We could use ARG here, but it seems impossible to compress multiple ARGs into one layer
ENV GOLLUM_VERSION=4.1.2 \
  GIT_VERSION=2.20.1-r0 \
  ALPINE_SDK_VERSION=1.0-r0 \
  ICU_DEV_VERSION=62.1-r0 \
  GOLLUM_PARAMS='' \
  CADDY_PARAMS='' \
  HOST=':80'

COPY --from=caddybuild --chown=1000:1000 /dist /

RUN \
  set -x && \
  apk --update add \
  # Need for gem install TODO move to docker.build?
  alpine-sdk=$ALPINE_SDK_VERSION icu-dev=$ICU_DEV_VERSION \
  # Needed for running gollum
  git=$GIT_VERSION \
  # Install gollum
  && gem install gollum -v $GOLLUM_VERSION \
  # cleanup apk cache
  && rm -rf /var/cache/apk/* \
  # Initialize wiki data.
  # Can be made persistent via -v /FOLDER/ON/HOST:/gollum/wikidata.
  && mkdir -p /gollum/wiki && mkdir -p /gollum/config \
  # Create caddyfile that can be mounted when running
  && touch /gollum/config/Caddyfile \
  # Make dirs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod a+rw /app \
  && chmod -R a+rw /gollum/ \
  # Allow caddy to bind to port 80 as non-root
  && setcap cap_net_bind_service=+ep $(which caddy) \
  && chmod +rx /startup.sh

RUN addgroup -g 1000 gollum && adduser -u 1000 -G gollum -s /bin/sh -D gollum \
 && chown -R gollum:gollum /app \
 && chown -R gollum:gollum /gollum \
 && chown gollum:gollum /startup.sh

USER gollum
WORKDIR  app

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start caddy and gollum
CMD /startup.sh
