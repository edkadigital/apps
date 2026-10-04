# memos

Helm chart for Memos on the official image: one Deployment, one volume and one
Service. It ships no database, ingress or monitoring.

The Edka package in the parent directory installs this chart. The chart also
installs on its own.

## Install

```bash
helm install memos .
```

Memos keeps its SQLite database on the volume and needs nothing else. Set
`instanceUrl` to the address people reach it on:

```bash
helm install memos . --set instanceUrl=https://notes.example.com
```

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` | `ghcr.io/usememos/memos` | The official image. |
| `image.tag` | `""` | Empty uses `appVersion`. |
| `image.pullPolicy` | `IfNotPresent` | |
| `fullnameOverride` | `""` | Name of every object. Empty uses the release name. |
| `containerPort` | `5230` | Port Memos listens on, and the port of the Service. |
| `instanceUrl` | `""` | Sets `MEMOS_INSTANCE_URL`, the external address Memos builds links with. |
| `existingSecret` | `""` | Optional. Every key becomes an environment variable, such as `MEMOS_DRIVER` and `MEMOS_DSN`. |
| `persistence.size` | `10Gi` | PersistentVolumeClaim with the name of the release. |
| `persistence.storageClass` | `""` | Empty uses the default of the cluster. |
| `persistence.mountPath` | `/var/opt/memos` | Also sets `MEMOS_DATA`. |
| `podLabels` | `{}` | Added to the pod. |
| `podAnnotations` | `{}` | Added to the pod. A changed value restarts the pod. |
| `resources` | `{}` | |
| `nodeSelector` | `{}` | |
| `tolerations` | `[]` | |

## How it works

- **One replica.** The SQLite database lives on one `ReadWriteOnce` volume, so
  the Deployment has one replica and the `Recreate` strategy. The old pod
  releases the volume before the new one starts.
- **No root.** The pod runs as user and group 10001, the `nonroot` user of the
  image, with `fsGroup: 10001`, a read-only root filesystem, no privilege
  escalation and no capabilities. Started this way, the entrypoint of the
  image leaves out its `chown` and `su-exec` step. `/tmp` is an `emptyDir`.
- **Configuration from the environment.** `MEMOS_DATA` and `MEMOS_PORT` come
  from `persistence.mountPath` and `containerPort`. Memos reads every setting
  of its command line from a `MEMOS_*` variable.
- **Probes** call `GET /healthz` on the HTTP port.

## Checks

The checks of this repository lint, render and install the chart with its
defaults.
