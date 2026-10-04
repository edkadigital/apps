# gitea

Helm chart for Gitea on the official rootless image: one Deployment, one
volume, a Service for HTTP and one for SSH. It ships no database, cache,
ingress or monitoring.

The Edka package in the parent directory installs this chart. The chart also
installs on its own.

## Install

The chart reads its secrets from a Secret that exists in the release namespace:

```bash
kubectl create secret generic gitea-config \
  --from-literal=ADMIN_PASSWORD='<password>' \
  --from-literal=GITEA__security__SECRET_KEY='<64 random characters>' \
  --from-literal=GITEA__security__INTERNAL_TOKEN='<64 random characters>' \
  --from-literal=GITEA__database__PASSWD='<database password>'
```

```bash
helm install gitea . \
  --set existingSecret=gitea-config \
  --set-string config.GITEA__database__DB_TYPE=postgres \
  --set-string config.GITEA__database__HOST=postgres-rw.postgres.svc.cluster.local:5432 \
  --set-string config.GITEA__database__NAME=gitea \
  --set-string config.GITEA__database__USER=gitea
```

With `config.GITEA__database__DB_TYPE=sqlite3` Gitea keeps its database on the
data volume, and the Secret needs no `GITEA__database__PASSWD`.

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` | `docker.gitea.com/gitea` | The official image. |
| `image.tag` | `""` | Empty uses `<appVersion>-rootless`. |
| `image.pullPolicy` | `IfNotPresent` | |
| `fullnameOverride` | `""` | Prefix of the object names. |
| `commonLabels` | `{}` | Added to every object. |
| `podLabels` | `{}` | Added to the pod. |
| `podAnnotations` | `{}` | Added to the pod. A changed value restarts the pod. |
| `existingSecret` | `""` | Required. Every key becomes an environment variable. `ADMIN_PASSWORD` is the administrator password. |
| `config` | `{}` | `GITEA__<section>__<KEY>` variables that are not secret. `APP_NAME` sets the site title. |
| `admin.username` | `gitea_admin` | Administrator account. |
| `admin.email` | `gitea@local.domain` | |
| `admin.passwordMode` | `keepUpdated` | `keepUpdated` sets the password to `ADMIN_PASSWORD` on every pod start. `initialOnly` creates the account once. |
| `service.http.port` | `3000` | Service `<fullname>`. |
| `service.ssh.enabled` | `false` | Adds the Service `<fullname>-ssh` and starts Gitea's SSH server on container port 2222. |
| `service.ssh.port` | `22` | Port of the SSH Service, and the port Gitea shows in clone addresses. |
| `persistence.enabled` | `true` | PersistentVolumeClaim `<fullname>` at `/var/lib/gitea`. |
| `persistence.size` | `10Gi` | |
| `persistence.storageClass` | `""` | Empty uses the default of the cluster. |
| `persistence.existingClaim` | `""` | Uses a claim that exists. |
| `resources` | `{}` | Applied to the init step and to Gitea. |
| `nodeSelector` | `{}` | |
| `tolerations` | `[]` | |

## How it works

- **One replica.** Repositories live on one `ReadWriteOnce` volume, so the
  Deployment has one replica and the `Recreate` strategy: the old pod releases
  the volume before the new one starts.
- **Configuration from the environment.** The image applies
  `GITEA__<section>__<KEY>` variables to `app.ini` on every start, so `app.ini`
  lives on an `emptyDir` and the values of the chart are the whole
  configuration. `GITEA__security__INSTALL_LOCK=true` is always set, so the web
  installer never runs.
- **Secrets by reference.** The pod reads `existingSecret` with `envFrom`. Keep
  `GITEA__security__SECRET_KEY` and `GITEA__security__INTERNAL_TOKEN` in it.
  Without them Gitea generates new ones into `app.ini` at every start, which
  signs every user out.
- **Restarts.** A change under `config` restarts the pod. The chart cannot read
  `existingSecret`, so a changed secret restarts the pod when a value under
  `podAnnotations` changes with it.
- **Administrator account.** An init step runs the entrypoint of the image,
  then `gitea migrate`, then creates the account or sets its password,
  depending on `admin.passwordMode`.
- **Probes** call `GET /api/healthz` on port 3000.
- **Rootless.** The pod runs as user and group 1000 with `fsGroup: 1000`, a
  read-only root filesystem, no privilege escalation and no capabilities.
  `/var/lib/gitea`, `/etc/gitea` and `/tmp` are volumes.

## Checks

`ci/test-values.yaml` and `ci/prerequisites.yaml` are what the checks of this
repository lint, render and install the chart with.
