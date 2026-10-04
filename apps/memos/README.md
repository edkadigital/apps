# Memos

[Memos](https://usememos.com) is a self-hosted note-taking app for short
Markdown notes on a timeline, with tags. This package installs one Memos
instance on the official image. Its SQLite database lives on one volume, so it
needs no database installation on the cluster.

## Requirements

- A storage class for the data volume. An empty setting uses the default
  storage class of the cluster.
- A Gateway traffic class, to reach Memos from outside the cluster.

## Settings

| Tab | Settings |
|---|---|
| General | Namespace, image tag and its updates |
| Storage | Storage class and size of the data volume |
| Resources | CPU and memory requests and limits |
| Placement | Node pool, and whether to tolerate its taints |
| Access | Hostname on a Gateway traffic class, and its certificate |

## What it creates

In the namespace of the instance:

- A Deployment with one replica of `ghcr.io/usememos/memos`, running as user
  and group 10001 with a read-only root filesystem.
- A PersistentVolumeClaim `<instance>`, mounted at `/var/opt/memos`. It holds
  the SQLite database `memos_prod.db` and the files Memos stores locally.
- A Service `<instance>` on port 5230.
- An `HTTPRoute` for the hostname, when access is on.

The package creates no Secret. Memos generates its own secret key at first
start and keeps it in its database.

## After the install

The first account created on a new instance becomes its admin. Until that
account exists, anyone who reaches Memos can create it. Create it as soon as
Memos runs. To do that before Memos is public, install with access off, open
Memos through `kubectl port-forward`, create the account, then turn on access.

Whether other people can sign up is a setting of Memos itself.

## Updates

The Deployment has one replica and replaces it on every change, so Memos is
unavailable while the pod restarts. Memos migrates its database when it starts.
By default, auto-update applies patch releases only.

## Where the facts come from

Checked on 2026-10-04, at release v0.31.0.

- **Image.** `ghcr.io/usememos/memos:0.31.0`, published for `linux/amd64`,
  `linux/arm64` and `linux/arm`. The image is Alpine with a `nonroot` user of
  UID and GID 10001, keeps its data in `/var/opt/memos` and sets
  `MEMOS_PORT=5230`.
  Source: [scripts/Dockerfile](https://github.com/usememos/memos/blob/v0.31.0/scripts/Dockerfile).
- **Running without root.** Started as root, the entrypoint changes the owner
  of `/var/opt/memos` and switches to 10001 with `su-exec`. Started as any
  other user, it leaves that step out.
  Source: [scripts/entrypoint.sh](https://github.com/usememos/memos/blob/v0.31.0/scripts/entrypoint.sh).
- **Configuration.** Every flag also reads a `MEMOS_*` environment variable:
  `MEMOS_DATA`, `MEMOS_PORT`, `MEMOS_INSTANCE_URL`, `MEMOS_DRIVER`, whose
  default is `sqlite`, and `MEMOS_DSN`.
  Source: [cmd/memos/main.go](https://github.com/usememos/memos/blob/v0.31.0/cmd/memos/main.go).
- **Database.** With SQLite, the database is `memos_prod.db` in the data
  directory. Memos migrates it at start, before it serves.
  Sources: [internal/profile/profile.go](https://github.com/usememos/memos/blob/v0.31.0/internal/profile/profile.go),
  [cmd/memos/main.go](https://github.com/usememos/memos/blob/v0.31.0/cmd/memos/main.go).
- **Health.** `GET /healthz` answers 200, and the probes use it.
  Source: [server/server.go](https://github.com/usememos/memos/blob/v0.31.0/server/server.go).
- **Secret key.** Memos generates it and stores it in the instance settings in
  its database.
  Source: [server/server.go](https://github.com/usememos/memos/blob/v0.31.0/server/server.go).
- **First account.** With no users, the first account created gets the admin
  role.
  Source: [server/api/v1/user_service.go](https://github.com/usememos/memos/blob/v0.31.0/server/api/v1/user_service.go).
- **License.** MIT.
  Source: [LICENSE](https://github.com/usememos/memos/blob/v0.31.0/LICENSE).
