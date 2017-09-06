FROM ubuntu:16.04

MAINTAINER Johannes Schnatterer <johannes@schnatterer.info>

# Additional gollom config: See https://github.com/gollum/gollum#configuration
# e.g '--config /home/usr/gollum/config/gollum.ru', in addition to -v /FOLDER/ON/HOST:/home/usr/gollum/config
ENV GOLLUM_PARAMS=''

RUN \
  apt-get update \
  && apt-get upgrade -y \
  # Install a more recent version of nginx
  #&& DEBIAN_FRONTEND=noninteractive apt-get install -y -q software-properties-common \
  #&& add-apt-repository -y ppa:nginx/stable \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    nginx \
    # Depdencies needed for gollum on Ubuntu : https://github.com/gollum/gollum/wiki/Installation#ubuntu-150415101604
    ruby ruby-dev make zlib1g-dev libicu-dev build-essential git cmake \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*  \
  # Install gollum
  && gem install gollum github-markdown \

  # Initialize wiki data.
  # Can be made persistent via -v /FOLDER/ON/HOST://wikidata. If so don't forget to call 'git init' in the path!
  # BTW you can customize 'gollum's' git user using this command in this directory:
  #  git config user.name 'John Doe' && git config user.email 'john@doe.org'
  && mkdir -p /gollum/wiki && mkdir -p /gollum/config && git init /gollum/wiki \

  # Create .htaccess file with default user test:test
  && printf 'test:$apr1$CqvfQba.$Xl.YaOfb13AqbSCcmoECR/' > /gollum/config/.htpasswd \

  # Authorize www-data user to the directories needed for running nginx and gollum
  && chown -R www-data:www-data /var/lib/nginx \
    /run \
    /etc/nginx/nginx.conf \
    /gollum \
  # Make logs world-writeable. On Openshift this won't run as user defined bellow...
  && chmod -R a+w /var/log/nginx \
  /var/lib/nginx\

  # Allow nginx to bind to port 80 as non-root
  && setcap CAP_NET_BIND_SERVICE=+eip $(which nginx)

# Config nginx as reverse proxy for gollum and to use basic auth
COPY nginx.conf /etc/nginx/nginx.conf

USER www-data

EXPOSE 80
EXPOSE 443
# Don't Expose gollum port 4567!

ENTRYPOINT nginx && /usr/local/bin/gollum /gollum/wiki $GOLLUM_PARAMS
