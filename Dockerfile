FROM ruby:2.4.1-alpine

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g.: -e GOLLUM_PARAMS=--config /gollum/config/gollum.ru", in addition to -v /FOLDER/ON/HOST:/gollum
ENV GOLLUM_PARAMS=""
#  e.g "--loglevel=DEBUG --configFile=/gollum/config/traefik.toml", in addition to -v /FOLDER/ON/HOST:/gollum
ENV TRAEFIK_PARAMS="--loglevel=DEBUG"

# Those are for the build only
ARG TRAEFIK_VERSION=v1.3.7

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
RUN mkdir -p /gollum/wiki && git init /gollum/wiki

# As we need to start two processes, create a startup script that starts one in the background  :-/
RUN printf " \
  (traefik --file.filename=/root/traefik-routes.toml $TRAEFIK_PARAMS)&  \n\
  gollum /gollum/wiki $GOLLUM_PARAMS" > /root/startup.sh \
&& chmod +x /root/startup.sh

# Create treafik route to gollum
COPY traefik-routes.toml /root/traefik-routes.toml

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start traefik and gollum
ENTRYPOINT /root/startup.sh
