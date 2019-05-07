# Build caddy from source, because binaries are published under a commercial license: https://caddyserver.com/pricing
# Starting with 1.0.0 we seem to no longer have to do this:  https://github.com/mholt/caddy/releases/tag/v1.0.0
# OTOH - with explicit plugin versions the build remains more deterministic than downloading the "latest" plugins via https://caddyserver.com/download
FROM golang:1.12.4 as caddybuild

# https://github.com/mholt/caddy/releases
ARG CADDY_VERSION="v1.0.0"
# https://github.com/BTBurke/caddy-jwt/releases
ARG CADDY_JWT_VERSION="v3.7.0"
# https://github.com/tarent/loginsrv/releases
ARG LOGINSRV_VERSION="v1.3.0"

ENV GO111MODULE=on
RUN mkdir -p /caddy
WORKDIR /caddy
RUN go mod init caddy
RUN go get -v github.com/mholt/caddy@$CADDY_VERSION

# Declares plugins and disables telemetry
ADD caddy.go .

# Check out deterministic versions of plugins that are tested to work with each other
RUN go get -v github.com/BTBurke/caddy-jwt@$CADDY_JWT_VERSION
RUN go get -v github.com/tarent/loginsrv/caddy@$LOGINSRV_VERSION

RUN CGO_ENABLED=0 go build -o caddy

# Prepare file structure for final image
RUN mkdir -p /dist/app && mkdir -p /dist/usr/local/bin
RUN cp caddy /dist/usr/local/bin/


# Declare common ruby base image for all ruby-stages
FROM ruby:2.6.2-alpine3.9 as gollum-ruby


FROM gollum-ruby as gollum-build

ARG ALPINE_SDK_VERSION=1.0-r0
ARG ICU_DEV_VERSION=62.1-r0
ARG GOLLUM_VERSION=4.1.4

COPY --from=caddybuild --chown=1000:1000 /dist /dist

# Need for gem install
RUN apk add  alpine-sdk=$ALPINE_SDK_VERSION icu-dev=$ICU_DEV_VERSION
# Install gollum
RUN gem install gollum -v $GOLLUM_VERSION
# Install proper markdown support (e.g. for tables, see https://github.com/gollum/gollum/issues/907)
RUN gem install github-markdown
RUN mv /usr/local/bundle /dist/usr/local/bundle

# Copy necessary libraries native extensions of ruby gems
RUN mkdir -p /dist/usr/lib
RUN cp /usr/lib/libicuuc.so* /dist/usr/lib/
RUN cp /usr/lib/libicui18n.so* /dist/usr/lib/
RUN cp /usr/lib/libicudata.so* /dist/usr/lib/

# As we need to start two processes, copy a startup script that starts only one process in the foreground  :-/
COPY startup.sh /dist/startup.sh
COPY Caddyfile /dist/app/
COPY config.rb /dist/app/
# Write gollum galores version number
COPY .git /gollum-galore/.git
RUN set -x; cd /gollum-galore && \
     POTENTIAL_TAG="$(git name-rev --name-only --tags HEAD)" \
     COMMIT="commit $(git rev-parse --short HEAD)"; \
     (if [ "${POTENTIAL_TAG}" != "undefined" ]; then echo "${POTENTIAL_TAG} (${COMMIT})"; \
      else echo "${COMMIT}"; fi) > /dist/app/version


FROM gollum-ruby

ARG VCS_REF
ARG SOURCE_REPOSITORY_URL
ARG GIT_TAG
ARG BUILD_DATE
# - Sources:
#   - https://pkgs.alpinelinux.org/packages?name=git&branch=v3.9
ARG GIT_VERSION=2.20.1-r0

# See https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="schnatterer" \
      org.opencontainers.image.url="https://hub.docker.com/r/schnatterer/gollum-galore/" \
      org.opencontainers.image.documentation="https://hub.docker.com/r/schnatterer/gollum-galore/" \
      org.opencontainers.image.source="${SOURCE_REPOSITORY_URL}" \
      org.opencontainers.image.version="${GIT_TAG}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="schnatterer" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="gollum-galore" \
      org.opencontainers.image.description="🍬 Gollum wiki with lots of sugar 🍬"

# - GOLLUM_PARAMS. Additional gollom config: See https://github.com/gollum/gollum#configuration
#    e.g '--config /config/gollum.ru', in addition to -v /FOLDER/ON/HOST:/gollum/config
# - CADDY_PARAMS e.g '-conf /gollum/config/Caddyfile', in addition to -v /FOLDER/ON/HOST:/gollum/config
ENV GOLLUM_PARAMS='' \
  CADDY_PARAMS='' \
  HOST=':80'

COPY --from=gollum-build --chown=1000:1000 /dist /

# Make sure /tmp is always writable, even in read-only containers.
VOLUME /tmp

RUN \
  set -x  \
  # Needed for running gollum
  && apk --update add git=$GIT_VERSION \
  # Needed for setcap
  libcap=2.26-r0 \
  # cleanup apk cache
  && rm -rf /var/cache/apk/* \
  # Initialize wiki data.
  && mkdir -p /gollum/wiki && mkdir -p /gollum/config \
  # Create caddyfile that can be mounted when running
  && touch /gollum/config/Caddyfile \
  # Make dirs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod a+rw /app \
  && chmod -R a+rw /gollum/ \
  # Allow caddy to bind to port 80 as non-root
  && setcap cap_net_bind_service=+ep $(which caddy) \
  && chmod +rx /startup.sh \
  # Don't run as root
  && addgroup -g 1000 gollum && adduser -u 1000 -G gollum -s /bin/sh -D gollum \
  && chown -R gollum:gollum /app \
  && chown -R gollum:gollum /gollum \
  && chown gollum:gollum /startup.sh \
  # Avoid "ArgumentError: Could not find a temporary directory" by ruby when uploading files
  && chown gollum:gollum /tmp \
  && chmod 700 /tmp

VOLUME /gollum/wiki

USER gollum
WORKDIR app

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start caddy and gollum
CMD ["/startup.sh"]
