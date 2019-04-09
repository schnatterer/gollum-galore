Gollum Galore behind a HTTP proxy
====

If running behind a proxy that takes care of TLS offloading, you might not want to re-encrypt the backend route to
Gollum galore (i.e. Caddy).

For this to work you'll have to set

* the `HOST` variable to `http://*` (or `*:80`) and
* `header_upstream X-Forwarded-Proto {>X-Forwarded-Proto}` in the `proxy` block for Requests to gollum.
* See [`Caddyfile`](config/Caddyfile).

The `Caddyfile` relies on the same `.htpasswd` file as the other demos (user demo, password demo) - 
see [JWT](../../README.md#jwt) for how to create your own password.  

In addition, it sets a constant `jwt-secret` so logins survive a restart.

The [`docker-compose.yaml`](docker-compose.yaml) implements a number of best practices for docker containers:

* `read-only` root file system enforcing integrity of the application files.
* `Caddyfile` mounted `read-only` enforcing integrity of the config files.
* specific `internal` network, blocking access to host ports and internet.
* `security-opt=no-new-privileges` avoids privilege escalation. 
* `restart` to provide better uptime in case of error.
* store wiki (git repo) in a docker volume.

Start with 

```bash
docker-compose up -d
```

Gollum galore can be reached vid HTTP on `172.1.1.2:80`
