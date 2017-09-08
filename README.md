# gollum-gallore

🍬 [Gollum wiki](https://github.com/gollum) with lots of sugar. 🍬

For now, HTTP basic auth and gzip compression. HTTPS support will be next.

Inspired by [suttang/gollum](https://github.com/suttang/docker-gollum) and [nginx](https://github.com/dockerfile/nginx/blob/master/Dockerfile).

# Getting to it

## Super simple setup

`docker run  -p 8080:80 schnatterer/gollum-galore`

* Serves gollum at `http://localhost:8080`,
* with HTTP basic auth user `test`, password `test `😲.
* The wiki data is stored in an anonymous volume.

## Advanced

`docker run -p80:80 -v ~/on/your/host/gollum:/gollum/ -e GOLLUM_PARAMS="--allow-uploads --live-preview" schnatterer/gollum-galore`

* Serves gollum at `http://localhost`,
* some of [gollum's command line options](https://github.com/gollum/gollum#configuration) are set
* with an HTTP basic auth file that you provide at `/on/your/host/gollum/config/.htpasswd`.
This can be created with `htpasswd -c /on/your/host/gollum/config/.htpasswd test` (where `test`) is the username, for example.
* The wiki data is stored in `/on/your/host/gollum/wiki` **and you called `git init` in this folder before starting the container**.
You can set the git author using `git config user.name 'John Doe' && git config user.email 'john@doe.org'`.

# Running on Kubernetes (Openshift)
You can run gollum-gallore easily on any Kubernetes cluster. It even runs on the [free starter plan of openshift v3](https://www.openshift.com/pricing/index.html).

You can find all necessary descriptors in [openshift-descriptors.yaml](openshift-descriptors.yaml). Most of them are standard kubernetes except for the route, which will work only on openshift.
It also shows how to specify gollum params and changes the default user to be `harry` and the password to be `sally` via a base64-encoded secret.

If you want to deploy it, all you got to do is 
```
oc new-project gollum-galore
kubectl apply -f openshift-descriptors.yaml

# For now you'll have to init the repo manually
kubectl exec -it gollum-galore-0 bash
git init /gollum/wiki/
```

Sidenote: There also is a [(discontinued) first version of an openshift template](https://github.com/schnatterer/gollum-galore/blob/59cae8ca93d127bed8efbe22d04c6b32860400dd/openshift-template.yaml).


