FROM ubuntu:16.04

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g.: -e GOLLUM_PARAMS=--config /gollum/config/gollum.ru", in addition to -v /FOLDER/ON/HOST:/gollum
ENV GOLLUM_PARAMS=""
#  e.g "--loglevel=DEBUG --configFile=/gollum/config/traefik.toml", in addition to -v /FOLDER/ON/HOST:/gollum
ENV TRAEFIK_PARAMS="--loglevel=DEBUG"

# Those are for the build only
ARG TRAEFIK_VERSION=v1.3.7

# Install dependencies
RUN apt-get update \
  && apt-get upgrade -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    wget \
    # Depdencies needed for gollum on Ubuntu : https://github.com/gollum/gollum/wiki/Installation#ubuntu-150415101604
    ruby ruby-dev make zlib1g-dev libicu-dev build-essential git cmake \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Install treafik
RUN wget -q -P /usr/local/bin https://github.com/containous/traefik/releases/download/$TRAEFIK_VERSION/traefik_linux-amd64 \
&& chmod +x /usr/local/bin/traefik_linux-amd64

# Install gollum
RUN gem install gollum github-markdown

# Initialize wiki data.
# Can be made persistent via -v /FOLDER/ON/HOST:/gollum. If so, don't forget to call "git init" in the path!
RUN mkdir -p /gollum/wiki && git init /gollum/wiki

# As we need to start two processes, create a startup script that starts one in the background  :-/
RUN printf " \
  (traefik_linux-amd64 --file.filename=/root/traefik-routes.toml $TRAEFIK_PARAMS)&  \n\
  /usr/local/bin/gollum /gollum/wiki $GOLLUM_PARAMS" > /root/startup.sh \
&& chmod +x /root/startup.sh

# Create treafik route to gollum
COPY traefik-routes.toml /root/traefik-routes.toml

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start traefik and gollum
ENTRYPOINT /root/startup.sh
