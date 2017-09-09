# gollum-gallore

🍬 [Gollum wiki](https://github.com/gollum) with lots of sugar. 🍬

HTTPS/TLS, HTTP2, gzip, HTTP basic, [etc](https://caddyserver.com/docs).

Inspired by [suttang/gollum](https://github.com/suttang/docker-gollum), enriched with sugar provided by the [caddy server](https://caddyserver.com/features).

# Getting to it

## Super simple setup

`docker run  -p 8080:80 schnatterer/gollum-galore`

* Serves gollum at `http://localhost:8080`,
* The wiki data is stored in an anonymous volume.

## Advanced

`docker run -p80:80 -e GOLLUM_PARAMS="--allow-uploads --live-preview" -e CADDY_PARAMS="-conf /gollum/config/Caddyfile -log stdout" -v ~/gollum:/gollum gollum-galore`

Combined with the following file on your host at `~/gollum/Caddyfile`
```
import /app/Caddyfile
basicauth / test test
```

* Serves gollum at `http://localhost`,
* some of [gollum's command line options](https://github.com/gollum/gollum#configuration) are set
*  The wiki data is stored in `~/gollum/wiki`.
You can set the git author using `git config user.name 'John Doe' && git config user.email 'john@doe.org'` in this folder.

# Running on Kubernetes (Openshift)
You can run gollum-gallore easily on any Kubernetes cluster. It even runs on the [free starter plan of openshift v3](https://www.openshift.com/pricing/index.html).

You can find all necessary descriptors in [openshift-descriptors.yaml](openshift-descriptors.yaml). Most of them are standard kubernetes except for the route, which will work only on openshift.
It also shows how to specify gollum params and activates basic auth for user `harry` and the password`sally` via a base64-encoded secret.

If you want to deploy it, all you got to do is
```
oc new-project gollum-galore
kubectl apply -f openshift-descriptors.yaml
```

Sidenote: There also is a [(discontinued) first version of an openshift template](https://github.com/schnatterer/gollum-galore/blob/59cae8ca93d127bed8efbe22d04c6b32860400dd/openshift-template.yaml).

# Architecture decisions

Why Caddy?
* Almost no configuration necessary
* Works as transparent proxy
* Provides HTTS/Letsencrypt out of the box

Evaluated Alternatives
* Traefik: Easy config, also for Letsencrypt, but didn't work as transparent proxy. Gollums 302 redirects lead to forward to port 4567 in browser, which is not exposed by container (by design!) See [Traefik proof of concept](https://github.com/schnatterer/gollum-galore/tree/traefik)
* NGINX: Worked as transparent proxy but letsencrypt required installing a seperate cron proxy. Lots of effort and larger docker image. See [NGINX proof of concept](https://github.com/schnatterer/gollum-galore/tree/nginx)
