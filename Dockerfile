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

RUN \
  apk --update add \
  # Need for gem install TODO move to docker.build?
  alpine-sdk icu-dev \
  # Needed for running gollum
  git \

  # Install gollum
  && gem install gollum  \

    # cleanup apk cache
  && rm -rf /var/cache/apk/* \

  # Install caddy
  && curl https://caddyserver.com/download/linux/amd64 | tar -xz  -C /usr/local/bin/ caddy \
  && chmod +x /usr/local/bin/caddy \

  # Initialize wiki data.
  # Can be made persistent via -v /FOLDER/ON/HOST:/gollum/wikidata.
  && mkdir -p /gollum/wiki && mkdir -p /gollum/config \

  # Create caddyfile that can be mounted when running
  && touch /gollum/config/Caddyfile \

  # Create base folder for startup script.
  && mkdir /app \
  # Make dirs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod a+rw /app \
  && chmod -R a+rw /gollum/wiki \

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
