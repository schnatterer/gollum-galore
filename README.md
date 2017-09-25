# gollum-gallore
[![schnatterer/gollum-galore@docker hub](https://images.microbadger.com/badges/image/schnatterer/gollum-galore.svg)](https://hub.docker.com/r/schnatterer/gollum-galore/)

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
* enables HTTP basic auth, allowing only user `test` password `test`
*  The wiki data is stored in `~/gollum/wiki`.
You can set the git author using `git config user.name 'John Doe' && git config user.email 'john@doe.org'` in this folder.

## HTTPS

The following makes Caddy challenge a certificate at letsencrypt.

`docker run -p80:80 -e 443:443 -e HOST=yourdomain.com -e CADDY_PARAMS=" -agree -email=you@yourdomain.com -log stdout" -v ~/gollum:/gollum gollum-galore`

This will of course only work if this is bound to yourdomain.com:80 and yourdomain:443.

See also [Automatic HTTPS - Caddy](https://caddyserver.com/docs/automatic-https).

On Openshift we have some other challenges to take. See bellow.

# Running on Kubernetes (Openshift)

## Simple setup

You can run gollum-gallore easily on any Kubernetes cluster. It even runs on the [free starter plan of openshift v3](https://www.openshift.com/pricing/index.html).

You can find all necessary descriptors in [openshift-descriptors-http.yaml](openshift-descriptors-http.yaml). Most of them are standard kubernetes except for the route, which will work only on openshift.
It also shows how to specify gollum params and activates basic auth for user `harry` and the password`sally` via a base64-encoded secret.

If you want to deploy it, all you got to do is
```
oc new-project gollum-galore
kubectl apply -f openshift-descriptors-http.yaml
```

You can query the URL of your route like so: ` oc get route gollum-galore-generated`.

As soon as your pod is ready your gollum wiki will be served at this location.

Note: This is HTTP only! If you're happy with the generated to domain, you can change the route to be `edge`. If you would like to use a custom domain, see bellow.

Sidenote: There also is a [(discontinued) first version of an openshift template](https://github.com/schnatterer/gollum-galore/blob/59cae8ca93d127bed8efbe22d04c6b32860400dd/openshift-template.yaml).

## HTTPS (Custom Domain)

Unfortunately, no luck getting Letsencrypt running on openshift, yet.

A promising setup would be

* Leave the generated route from the simple setup in place and use it to create a CNAME record with your DNS provider.
* Create another `passthrough` route to our `gollum-galore` service, which should be able to pass the `tls-sni-challenge`.
* Use the following params to start caddy
```yaml
name: CADDY_PARAMS
value: -log stdout -agree -disable-http-challenge -email=you@yourdomain.com
```

However, even though it's `passthrough`, openshift always returns its own certificate, leading to a failure in the `tls-sni-challenge`.

The http-challenge is not possible, because with `passthrough` routes on openshift, it's only possible to either block traffic or redirect it to port 443.

One option would be the `dns-challenge`. [Caddy supports a number of providers](https://caddyserver.com/docs/automatic-https#dns-challenge).

If you not happen to be at one of those providers, you could can create an `edge` route an either create and upload your certificates manually or create this `edge` route without specifying any certificate files. Then openhshift ships its own certificate (this results in a warning in the browser)

A finaly option is to use a self signed certifcate (this will also result in a warning in the browser).
However, this setup at least proofs the concept: `yourdomain.com` delivered with a certificate created by Caddy.
You can try this out by changing yourdomain.com in [`openshift-descriptors-https-self-signed.yaml`](openshift-descriptors-https-self-signed.yaml) and rolling it out to the cluster like so:
`kubectl apply -f openshift-descriptors-https-self-signed.yaml`

Don't forget
* to create the DNS CNAME entry as described above,
* If you're pod is already running, delete it to trigger a new deployment (our necessary, because we use a `StatefulSet` here):
`kubectl delete pod gollum-galore-0`


# Architecture decisions

## Why Caddy?
* Almost no configuration necessary
* Works as transparent proxy
* Provides HTTS/Letsencrypt out of the box

Evaluated Alternatives
* Traefik: Easy config, also for Letsencrypt, but didn't work as transparent proxy. Gollums 302 redirects lead to forward to port 4567 in browser, which is not exposed by container (by design!) See [Traefik proof of concept](https://github.com/schnatterer/gollum-galore/tree/traefik)
* NGINX: Worked as transparent proxy but letsencrypt required installing a seperate cron proxy. Lots of effort and larger docker image. See [NGINX proof of concept](https://github.com/schnatterer/gollum-galore/tree/nginx)


## Why two processes in one Container?
* Gollum wiki is not indended to handle features such as HTTPS and auth -> We need a reverse proxy for that.
* It's just easier to ship this as one artifact.
* Gollum is not really scaleable like this anyway.
* You can run it on the free starter plan of openshift v3 :-)
