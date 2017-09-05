# gollum-gallore

🍬 [Gollum wiki](https://github.com/gollum) with lots of sugar. 🍬

For now, HTTP basic auth and gzip compression. HTTPS support will be next.

Inspired by [suttang/gollum](https://github.com/suttang/docker-gollum) and [nginx](https://github.com/dockerfile/nginx/blob/master/Dockerfile).

# Getting to it

## Super simple setup

`docker run schnatterer/gollum-galore -p 8080:80`

* Serves gollum at localhost:8080, 
* with HTTP basic auth user `test`, password `test `😲. 
* The wiki data is stored in an anonymous volume.

## Advanced

`docker run -p80:80 -v ~/on/your/host/gollum:/gollum/ -e GOLLUM_PARAMS="--allow-uploads --live-preview" schnatterer/gollum-galore`

* Serves gollum at `localhost:8080`, 
* some of [gollum's command line options](https://github.com/gollum/gollum#configuration) are set
* with an HTTP basic auth file that you provide at `/on/your/host/gollum/config/.htpasswd`.  
This can be created with `htpasswd -c /on/your/host/gollum/config/.htpasswd test` (where `test`) is the username, for example.
* The wiki data is stored in `/on/your/host/gollum/wiki` **and you called `git init` in this folder before starting the container**.  
You can set the git author using `git config user.name 'John Doe' && git config user.email 'john@doe.org'`.
