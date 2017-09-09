FROM ruby:2.4.1-alpine

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g '--config /home/usr/gollum/config/gollum.ru', in addition to -v /FOLDER/ON/HOST:/home/usr/gollum/config
ENV GOLLUM_PARAMS=''
ENV CADDY_PARAMS=''
ENV HOST=':80'

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

  # As we need to start two processes, create a startup script that starts one in the background  :-/
  # In addition, make sure there is git repo in the wiki folder
  # BTW you can customize 'gollum's' git user using this command in this directory:
  #  git config user.name 'John Doe' && git config user.email 'john@doe.org'
  && printf " \
  (git init /gollum/wiki)& \n\
  (caddy $CADDY_PARAMS)& \n\
  gollum /gollum/wiki $GOLLUM_PARAMS" > /startup.sh \
  && chmod +rx /startup.sh

COPY Caddyfile /app
WORKDIR  app

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

# Start caddy and gollum
CMD /startup.sh
