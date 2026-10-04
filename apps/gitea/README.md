# Gitea

[Gitea](https://about.gitea.com) is a self-hosted Git service with issues, pull
requests, packages and CI. This package installs one Gitea instance on the
official rootless image. Repositories live on one volume, and the database is a
PostgreSQL installation of the cluster.

## Requirements

- A PostgreSQL installation on the cluster, with a database and a user for
  Gitea.
- A Gateway traffic class, to reach Gitea from outside the cluster.

## Settings

| Tab | Settings |
|---|---|
| General | Namespace, image tag and its updates, site title, administrator account, registration and sign-in policy, Git over SSH |
| Database | PostgreSQL installation, database and user |
| Storage | Storage class and size of the data volume |
| Resources | CPU and memory requests and limits |
| Placement | Node pool, and whether to tolerate its taints |
| Access | Hostname on a Gateway traffic class, and its certificate |

## What it creates

In the namespace of the instance:

- A Deployment with one replica of `docker.gitea.com/gitea`, running as user
  1000 with a read-only root filesystem.
- A PersistentVolumeClaim `<instance>`, mounted at `/var/lib/gitea`.
- A Service `<instance>` on port 3000, and `<instance>-ssh` on port 22
  when Git over SSH is on.
- A Secret `<instance>-config` with the administrator password, Gitea's
  `SECRET_KEY` and `INTERNAL_TOKEN`, and the database password.
- An `HTTPRoute` for the hostname, when access is on.

## After the install

Sign in as the administrator. The username is the one set in the form, and the
password is on the app page under **Admin password**. Gitea creates the account
once. A password changed in Gitea afterwards stays changed, and the app page
keeps showing the first one.

Git over SSH is served inside the cluster. Reaching it from outside takes a TCP
route or a load balancer, which this package does not create.

## Updates

The Deployment has one replica and replaces it on every change, so Gitea is
unavailable while the pod restarts. An init step runs `gitea migrate` before
the new version starts.

## Where the facts come from

Checked on 2026-10-01.

- **Image.** `docker.gitea.com/gitea:1.26.4-rootless`, published for
  `linux/amd64` and `linux/arm64`. The container runs as `1000:1000`, keeps its
  data in `/var/lib/gitea`, its configuration in `/etc/gitea` and temporary
  files in `/tmp/gitea`. HTTP listens on 3000 and the built-in SSH server on
  2222.
  Sources: [rootless installation](https://docs.gitea.com/installation/install-with-docker-rootless),
  [Dockerfile.rootless](https://github.com/go-gitea/gitea/blob/release/v1.26/Dockerfile.rootless).
- **Configuration.** The image applies `GITEA__<section>__<KEY>` environment
  variables to `app.ini` on every start. `APP_NAME` sets the site title.
  Sources: [installation with Docker](https://docs.gitea.com/installation/install-with-docker),
  [docker-setup.sh](https://github.com/go-gitea/gitea/blob/release/v1.26/docker/rootless/usr/local/bin/docker-setup.sh).
- **Health.** `GET /api/healthz` answers 200 without authentication, and the
  probes use it.
  Source: [go-gitea/gitea#18465](https://github.com/go-gitea/gitea/pull/18465).
- **Administrator account.** `gitea admin user create --admin` creates it. The
  command fails for an account that exists, so the init step checks
  `gitea admin user list --admin` first.
  Source: [command line](https://docs.gitea.com/administration/command-line).
- **License.** MIT.
  Source: [LICENSE](https://github.com/go-gitea/gitea/blob/main/LICENSE).
