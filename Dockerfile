FROM ruby:2.4.1-alpine

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g.: -e GOLLUM_PARAMS=--config /gollum/config/gollum.ru", in addition to -v /FOLDER/ON/HOST:/gollum
ENV GOLLUM_PARAMS=""
#  e.g "--loglevel=DEBUG --configFile=/gollum/config/traefik.toml", in addition to -v /FOLDER/ON/HOST:/gollum
ENV TRAEFIK_PARAMS="--loglevel=DEBUG"

# Those are for the build only
ARG TRAEFIK_VERSION=v1.3.8

# As we need to start two processes, copy a startup script that starts only one process in the foreground  :-/
# BTW you can customize 'gollum's' git user using the following command in the (mounted) /gollum/wiki folder:
#  git config user.name 'John Doe' && git config user.email 'john@doe.org'
COPY startup.sh /

RUN \
  apk --update add \
  # Need for gem install TODO move to docker.build?
  alpine-sdk icu-dev \
  # Needed for running gollum
  git \
  # Needed for caddy
  openssh-client \

  # Install gollum
  && gem install gollum  \

    # cleanup apk cache
  && rm -rf /var/cache/apk/*

# Install treafik
RUN wget -q -O /usr/local/bin/traefik https://github.com/containous/traefik/releases/download/$TRAEFIK_VERSION/traefik_linux-amd64 \
&& chmod +x /usr/local/bin/traefik

# Allow traefik to bind to port 80 as non-root
RUN setcap cap_net_bind_service=+ep $(which usr/local/bin/traefik)

# Install gollum
RUN gem install gollum

# Initialize wiki data.
# Can be made persistent via -v /FOLDER/ON/HOST:/gollum. If so, don't forget to call "git init" in the path!
RUN mkdir -p /gollum/wiki && git init /gollum/wiki \

 # Create base folder for startup script.
  && mkdir /app \
  # Make dirs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod a+rw /app \
  && chmod -R a+rw /gollum/wiki \
  && chmod +rx /startup.sh

# Create treafik route to gollum
COPY traefik-routes.toml /app
WORKDIR app

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start traefik and gollum
ENTRYPOINT /startup.sh
