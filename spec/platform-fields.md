# Platform fields

Edka acts on some field names. A package that uses these names gets the
behaviour described here, in every organization and on every cluster.
A package with `standard` gets the namespace, image update, resources and
placement fields, and the storage, access and PostgreSQL fields it asks for,
without writing them. See [Standard parts](package-format.md#standard-parts).
The blocks below are for a package that writes the full template.

## Namespace

```yaml
- name: "namespace"
  config:
    type: "dynamic-select"
    label: "Namespace"
    default: "memos"
    data_source: "cluster-namespaces"
    required: true
    editable: false
    validation: "kubernetes-name"
```

The installer picks an existing namespace or types a new one. Any namespace of
the cluster is allowed. Without this field the app is installed into a
namespace named after the instance.

## Resources

Four string fields with Kubernetes quantities: `cpu_request`, `memory_request`,
`cpu_limit`, `memory_limit`. A package with more than one workload prefixes
them: `web_cpu_request`, `worker_cpu_request`.

## Placement

```yaml
- name: "node_pool_name"
  config:
    type: "dynamic-select"
    label: "Node pool"
    data_source: "cluster-node-pools"
    required: false
- name: "tolerate_node_pool_taints"
  config:
    type: "boolean"
    label: "Tolerate node pool taints"
    default: true
```

When the installer selects a node pool, Edka sets `node_pool_selector_enabled`,
`node_pool_selector_key`, `node_pool_selector_value`,
`node_pool_tolerations_enabled` and `node_pool_tolerations`. The template passes
them to the chart:

```mustache
{{#node_pool_selector_enabled}}
nodeSelector:
  {{{ node_pool_selector_key }}}: "{{{ node_pool_selector_value }}}"
{{/node_pool_selector_enabled}}
{{#node_pool_tolerations_enabled}}
tolerations:
{{#node_pool_tolerations}}
  - key: "{{{ key }}}"
    operator: Equal
    value: "{{{ value }}}"
    effect: "{{{ effect }}}"
{{/node_pool_tolerations}}
{{/node_pool_tolerations_enabled}}
{{^node_pool_tolerations_enabled}}
tolerations: []
{{/node_pool_tolerations_enabled}}
```

## Access

| Field | Type | Notes |
|---|---|---|
| `access_enabled` | boolean | Whether the app is published on a hostname. |
| `ingress_class` | `dynamic-select` on `cluster-ingress-classes` | The traffic class. `show_if: "access_enabled"`. |
| `hostname` | string, `validation: "domain"` | `show_if: "access_enabled"`. |
| `use_cluster_issuer` | boolean | Optional. Requests a Let's Encrypt certificate for the hostname when no wildcard certificate of the cluster covers it. |
| `https_only` | boolean | Optional. `false` serves the route on HTTP as well. Without the field, HTTP redirects to HTTPS. |

From the traffic class, Edka sets `ingress_class_is_gateway`, `gateway_name` and
`gateway_namespace`. The template creates an `HTTPRoute` under both flags:

```mustache
{{#access_enabled}}
{{#ingress_class_is_gateway}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  namespace: {{{ namespace }}}
  name: {{{ release_name }}}-web
spec:
  parentRefs:
    - name: {{{ gateway_name }}}
      namespace: {{{ gateway_namespace }}}
  hostnames:
    - "{{{ hostname }}}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: {{{ release_name }}}
          port: 5230
{{/ingress_class_is_gateway}}
{{/access_enabled}}
```

Edka attaches the certificate and adds the redirect from HTTP to HTTPS around
the route. A hostname under a domain of the cluster uses the wildcard
certificate of that domain. Any other hostname gets a certificate when the form
has `use_cluster_issuer` and it is on, which is how `edka apps init --with
access` writes it. A package creates no `Ingress` and no certificate objects.

## Storage

```yaml
- name: "storage_class"
  config:
    type: "dynamic-select"
    label: "Storage class"
    data_source: "cluster-storage-classes"
    required: false
    editable: false
- name: "storage_size"
  config:
    type: "string"
    label: "Storage size"
    default: "10Gi"
    required: true
```

The two fields go in a `storage` tab. An empty `storage_class` takes the
default of the cluster. The chart creates the PersistentVolumeClaim and sets
`fsGroup` on the pod. A new volume belongs to root. With `fsGroup`, the volume
belongs to that group and the container runs with it, so a container that does
not run as root can write to the volume:

```yaml
securityContext:
  fsGroup: {{ .Values.persistence.fsGroup }}
  fsGroupChangePolicy: OnRootMismatch
```

Hetzner Cloud volumes start at 10 GB. A smaller size in the form still gets a
10 GB volume there.

## Image updates

With these fields and an `auto_update` block, Edka's agent in the cluster can
move the image tag:

| Field | Type | Notes |
|---|---|---|
| `auto_update_enabled` | boolean | Off by default. |
| `auto_update_policy` | select: `patch`, `minor`, `major`, `all`, `custom` | `show_if: "auto_update_enabled"` |
| `auto_update_custom_pattern` | string | A `glob:` or `regexp:` filter, for the `custom` policy. |
| `auto_update_frequency` | select: `5m`, `30m`, `1h`, `6h`, `24h` | Time between checks. |

The `HelmChart` carries them as annotations:

```yaml
annotations:
  edka.io/auto-update-enabled: "{{{ auto_update_enabled }}}"
  edka.io/auto-update-policy: "{{{ auto_update_policy }}}"
  edka.io/auto-update-frequency: "{{{ auto_update_frequency }}}"
  edka.io/auto-update-custom-pattern: "{{{ auto_update_custom_pattern }}}"
  edka.io/auto-update-targets: |-
    {{{ auto_update_targets }}}
```

## PostgreSQL

An app uses a PostgreSQL installation that exists on the cluster. The installer
selects the installation, a database and a user. Edka reads the password of
that user and builds the connection string.

```yaml
- name: "postgres_instance"
  config:
    type: "dynamic-select"
    label: "PostgreSQL installation"
    data_source: "cluster-postgresql-instances"
    required: true
    set_fields:
      postgres_host: "metadata.host"
      postgres_port: "metadata.port"
      postgres_schema: "metadata.schema"
      postgres_ssl_enabled: "metadata.sslEnabled"
      postgres_ssl_reject_unauthorized: "metadata.sslRejectUnauthorized"
- name: "postgres_database"
  config:
    type: "dynamic-select"
    label: "PostgreSQL database"
    data_source: "cluster-postgresql-databases"
    depends_on: "postgres_instance"
    required: true
    set_fields:
      postgres_database: "metadata.database"
- name: "postgres_user"
  config:
    type: "dynamic-select"
    label: "PostgreSQL user"
    data_source: "cluster-postgresql-users"
    depends_on: "postgres_instance"
    required: true
    set_fields:
      postgres_user: "metadata.username"
      postgres_password_secret_namespace: "metadata.passwordSecretNamespace"
      postgres_password_secret_name: "metadata.passwordSecretName"
      postgres_password_secret_key: "metadata.passwordSecretKey"
```

The targets of `set_fields` are `hidden` fields: `postgres_host`,
`postgres_port`, `postgres_schema`, `postgres_ssl_enabled`,
`postgres_ssl_reject_unauthorized`, `postgres_password_secret_name`,
`postgres_password_secret_namespace` and `postgres_password_secret_key`. Edka
sets them again from the selected installation at every install and edit.
`postgres_ssl_enabled` is `true` when the installation accepts only TLS
connections.

Two more hidden fields, both with `secret: true` and an empty default, receive
what Edka resolves at every render:

| Field | Value |
|---|---|
| `postgres_password` | The password of the selected user. |
| `database_url` | `postgresql://user:password@host:port/database`, with `?sslmode=` when the installation uses TLS. |

A template writes them into its Secret:

```yaml
stringData:
  DATABASE_URL: |-
    {{{ database_url }}}
```

Edka takes the Secret that holds the password from the installation the
installer selected. A package cannot point these fields at another Secret.

`edka apps init --with postgres` writes the whole block.

## Valkey

The same pattern with `valkey_instance` on `cluster-valkey-instances`. Targets:
`valkey_host`, `valkey_port`, `valkey_database`, `valkey_auth_enabled`,
`valkey_username`, `valkey_password_secret_namespace`,
`valkey_password_secret_name`, `valkey_password_secret_key`. Edka resolves
`valkey_password`, and `redis_url` when the form declares it.

## ClickHouse

The same pattern with `clickhouse_instance` on `cluster-clickhouse-instances`.
Targets: `clickhouse_host`, `clickhouse_scheme`, `clickhouse_http_port`,
`clickhouse_database`, `clickhouse_user`,
`clickhouse_password_secret_namespace`, `clickhouse_password_secret_name`,
`clickhouse_password_secret_key`. Edka resolves `clickhouse_password`, and
`clickhouse_database_url` when the form declares it.

## Generated secrets

```yaml
- name: "admin_password"
  config:
    type: "password"
    label: "Admin password"
    generate: true
    length: 24
    required: true
    editable: false
    retrievable: true
```

- A generated value has letters and digits. `format: "hex"` gives lowercase
  hex, and `requireSpecialCharacter: true` adds characters from `!#%+-_.~`.
- A generated value is one line with nothing YAML treats specially, so
  `"{{{ field }}}"` inside a quoted scalar is safe.
- `retrievable: true` lets an authorized user read the value on the app page.
  Use it for a credential a person signs in with.

## Data sources

Values of `data_source` for a `dynamic-select` field:

| Data source | Options |
|---|---|
| `cluster-namespaces` | Namespaces of the cluster |
| `cluster-storage-classes` | Storage classes |
| `cluster-ingress-classes`, `cluster-gateway-classes` | Envoy Gateway traffic classes of the cluster |
| `cluster-gateway-wildcard-domains` | Wildcard domains with a certificate |
| `cluster-node-pools` | Node pools |
| `cluster-postgresql-instances`, `cluster-postgresql-databases`, `cluster-postgresql-users` | PostgreSQL installations and what they hold |
| `cluster-valkey-instances` | Valkey installations |
| `cluster-clickhouse-instances` | ClickHouse installations |

A custom app can also use `cluster-hermes-agent-instances`,
`cluster-environment-agents` and `organization-object-storage-integrations`.
