# App package format

An Edka app is a package: one directory that holds everything Edka needs to show
the app in a catalog, ask for its settings and install it on a cluster.

Current format version: **2**.

```
memos/
  template.yaml          # required: catalog entry, settings form, manifests
  chart/                 # optional: the Helm chart the template installs
    Chart.yaml
    values.yaml
    templates/
    ci/                  # community: values and objects the install check uses
  README.md              # optional for an organization, required for the community
  icon.svg               # optional: icon.svg or icon.png, one of them
  test/answers.yaml      # optional for an organization, required for the community
```

The same package installs in two places. Published to an organization, it is a
custom app, private to that organization. Listed in the community catalog,
every Edka organization can install it. The format is the same, and the community adds
rules that are checked before listing. See [Community listing](#community-listing).

## Limits

| What | Limit |
|---|---|
| Files in a package | 200 |
| All files together | 1 MB |
| `template.yaml` | 300 KB |
| `inputs_schema` | 100 KB |
| `README.md`, the icon | 100 KB each |
| The chart, packed | 512 KB |
| One rendered template | 4 MB |

Paths use forward slashes, with no `.` or `..` segments. Every file except
`icon.png` is UTF-8 text. An SVG icon is a plain drawing: no scripts, no
`foreignObject`, no event handlers.

## `template.yaml`

One YAML document. Unknown keys are rejected. YAML anchors and aliases are not
allowed anywhere in a package.

| Key | Type | Required | Notes |
|---|---|---|---|
| `format_version` | number | yes | `2` |
| `name` | string | yes | Name shown in the catalog. 2 to 60 characters. Stays the same across versions. |
| `slug` | string | yes | Lowercase letters, digits and single hyphens, starting with a letter, 2 to 40 characters. The chart carries the same name. Stays the same across versions. |
| `description` | string | yes | One or two sentences, 10 to 255 characters. |
| `version` | string | yes | Version of the package, as SemVer. The chart carries the same version. |
| `app_version` | string | yes | Version of the app the package installs, such as the image tag. |
| `category`, `subcategory` | string | no | One lowercase word each, such as `database` or `web`. |
| `tags` | string[] | no | Up to 10 lowercase words. |
| `icon` | string | no | Name of a glyph, used when the package ships no icon file. |
| `links` | `{label, url}[]` | no | Up to 10. `https` only. |
| `upstream` | `{repository, license}` | community | Where the app comes from and its license. |
| `maintainers` | `{github}[]` | community | GitHub handles of the people who keep the package current. |
| `standard` | object | no | The parts Edka writes. See [Standard parts](#standard-parts). |
| `values` | string | no | With `standard`: chart values of the app, as a Mustache template. |
| `images` | string[] | community | Image repositories the package runs, without tags. With `standard`, its image is listed already. |
| `platforms` | string[] | community | `linux/amd64`, `linux/arm64` |
| `required_addons` | string[] | no | Add-ons that must be installed first. |
| `auto_update` | object | no | Image tags Edka may update. See [Image updates](#image-updates). |
| `configuration_tabs` | string[] | without `standard` | Tabs of the settings form, in order. With `standard`, Edka orders the tabs and the key is rejected. |
| `inputs_schema` | map | without `standard` | The fields of each tab. With `standard`, the fields of the app only. |
| `endpoints` | list | no | Addresses shown on the app page. |
| `exposure_schema` | object | no | Structured endpoint declarations. |
| `runtime_selectors` | object | no | How Edka finds what the app runs. |
| `metrics_schema` | object | no | Metrics shown on the app page. |
| `multi_instance` | boolean | no | `false` allows one instance per cluster. |
| `template` | string | without `standard` | The manifests, as a Mustache template. With `standard`, the objects of the app only, such as a Secret. |

A name or slug that another app in the same catalog already uses is rejected,
and so are the names of Edka's own apps.

## Standard parts

Most of a package is the same for every app: the Namespace, the `HelmChart`
that installs `./chart`, the image, resources and placement settings, the
HTTPRoute and the endpoints. With `standard`, Edka writes these, and the
package holds only what is particular to the app.

```yaml
standard:
  image: "ghcr.io/usememos/memos"
  tag: "0.31.0@sha256:24c2707ddd8fbd2ceaa7a61ecab86a53cdcde640b24ce572b73da14b00b5785f"
  port: 5230
  with: ["storage", "access"]
  defaults:
    memory_limit: "1Gi"

values: |
  {{#access_enabled}}
  instanceUrl: "https://{{{ hostname }}}"
  {{/access_enabled}}
```

| Key | Notes |
|---|---|
| `image` | Image repository without a tag. |
| `tag` | Default of the image tag field. A community package pins the digest after the tag. |
| `port` | Port of the Service named `{{{ release_name }}}`. The HTTPRoute and the address inside the cluster use it. |
| `with` | Any of `storage`, `access` and `postgres`. |
| `defaults` | New defaults for standard fields, by field name. |

What Edka writes:

| Part | Fields | Objects and values |
|---|---|---|
| Always | `namespace`, `image_tag` and the auto-update fields in `general`; the `resources` and `placement` tabs | The Namespace, and the `HelmChart` named `{{{ release_name }}}` with the auto-update annotations. Its values set `fullnameOverride`, `image.repository`, `image.tag`, `podLabels`, `podAnnotations` with `checksum/secrets`, `resources`, `nodeSelector` and `tolerations`. An image update target for `image.tag`. An endpoint for `http://{{{ release_name }}}.{{{ namespace }}}.svc.cluster.local:<port>`. Runtime selectors for the Namespace, the workload and the Service named `{{{ release_name }}}` |
| `storage` | `storage_class` and `storage_size` in the `storage` tab | `persistence.size` and `persistence.storageClass`, and a runtime selector for the claim named `{{{ release_name }}}` |
| `access` | `access_enabled`, `ingress_class`, `hostname` and `use_cluster_issuer` in the `access` tab | An HTTPRoute from the hostname to the Service on `port`, and an `External URL` endpoint |
| `postgres` | The PostgreSQL fields in the `database` tab, including `database_url` | |

The chart of a package with `standard` reads those values: every key listed
above is declared in `values.yaml`, the Service and the claim are named after
`fullnameOverride`, and the pod template carries `podLabels` and
`podAnnotations`. `edka apps init` writes a chart that does.

The rest of the package:

- `inputs_schema` holds the fields of the app. A field in a tab that Edka
  fills, such as `general` or `access`, comes after the standard ones. A tab
  of the app's own comes after `general`. A field may not take the name of a
  standard field: set `standard.defaults` to change its default.
- `template` holds the other objects, such as the Secret the chart reads. It
  may not hold a Namespace or a `HelmChart`.
- `values` holds the chart values of the app. It may not set a key that Edka
  writes.
- `endpoints`, `images`, `auto_update` targets and `runtime_selectors` are
  added to the ones Edka writes.

## The settings form

`inputs_schema` maps each tab to a list of fields. Every tab in
`configuration_tabs` has fields, and every tab with fields is listed.

```yaml
configuration_tabs:
  - "general"

inputs_schema:
  general:
    - name: "image_tag"
      config:
        type: "string"
        label: "Image tag"
        description: "Tag of ghcr.io/usememos/memos"
        default: "0.25.1"
        required: true
```

A field name is lowercase letters, digits and underscores, starting with a
letter. It is the name of the variable in the template: `{{{ image_tag }}}`.

### Field types

| Type | In the form |
|---|---|
| `string` | Text input |
| `textarea` | Multi-line text |
| `number` | Number, bounded by `min` and `max` |
| `boolean` | Switch |
| `select` | One of `options`, each a string or `{label, value}` |
| `dynamic-select` | One of the options Edka reads from the cluster, named by `data_source` |
| `password` | Secret input. See [Secrets](#secrets). |
| `hidden` | Not shown. Holds a value another field or Edka fills in. |

### Field settings

| Key | Notes |
|---|---|
| `type`, `label` | Required. |
| `description`, `placeholder`, `help` | Text shown with the field. |
| `default` | String, number or boolean. Not allowed on a secret field. Must pass the field's own rules. |
| `required` | A blank value fails validation. |
| `editable` | `false` locks the field after install. |
| `options` | For `select`. |
| `min`, `max`, `minLength`, `maxLength` | Bounds. |
| `validation` | `domain`, `email`, `url`, `kubernetes-name`, `s3-object-prefix`, `semver` |
| `show_if` | When the field is shown. See below. |
| `data_source`, `depends_on`, `set_fields` | For `dynamic-select`. See [platform-fields.md](platform-fields.md). |
| `set_fields_by_value` | For `select`: values other fields take when an option is chosen. |
| `secret` | Treats a field that is not a `password` as a secret. |
| `generate`, `length`, `format`, `requireSpecialCharacter` | For a `password` Edka generates. |
| `retrievable` | An authorized user can read the stored value on the app page. |

### `show_if`

One or more clauses joined by `&&`:

- `field_name`: the field is `true`
- `!field_name`: the field is not `true`
- `field_name === 'value'`: the field holds that text

Every field a clause names exists in the form. A field that is not shown is
left out of validation.

## Variables

A template, an endpoint and a runtime selector can use three kinds of variables.
Anything else is rejected, with the line it appears on.

**Fields.** Every field of the form, by its name.

**Derived from fields.** Edka adds these for every field, so a package declares
nothing for them:

- `<field>_base64`: the value, base64-encoded, for `data` in a Secret
- `<field>_is_<option>`: `true` when a `select` field holds that option. Mustache
  cannot compare values, so a template branches on these.
  `storage_type_is_pvc` belongs to the field `storage_type` and its option `pvc`.
  Characters other than letters and digits in the option become `_`.

**Platform variables.** Edka sets these for every instance. A field cannot take
one of their names.

| Variable | Value |
|---|---|
| `release_name` | Name of the instance in the cluster. Name every object after it. |
| `release_name_label` | The same, safe as a label value. |
| `namespace` | Namespace the app is installed into. Declare a `namespace` field to let the installer choose it. |
| `instance_slug` | Slug of the instance. |
| `app_id` | ID of the instance, for `runtime_selectors`. |
| `app_instance_id`, `app_instance_id_label` | ID of the installed app, raw and as a label value. |
| `catalog_app_id`, `catalog_app_id_label` | ID of the catalog entry. |
| `version`, `app_version` | The two versions of the package. |
| `ingress_class_is_gateway`, `gateway_name`, `gateway_namespace`, `tailscale_hostname_label` | Set from the traffic class the installer chose. See [platform-fields.md](platform-fields.md). |
| `webhook_ingress_class_is_gateway`, `webhook_gateway_name`, `webhook_gateway_namespace` | The same for a `webhook_ingress_class` field. |
| `node_pool_selector_enabled`, `node_pool_selector_key`, `node_pool_selector_value` | Set from the node pool the installer chose. |
| `node_pool_tolerations_enabled`, `node_pool_tolerations` with `key`, `value`, `effect` | Tolerations for that node pool. |
| `network_policy_enabled` | `true` unless the configuration says otherwise. |
| `auto_update_targets` | The `auto_update` block as JSON, for the annotation Edka's agent reads. |
| `secrets_checksum` | 32 hex characters that change when a secret field of the instance changes. See [Secrets](#secrets). |

## The template

`template` renders to Kubernetes manifests separated by `---`.

- `{{{ var }}}` writes a value. Use three braces. Two braces escape HTML and
  break values that hold `&`, `<` or quotes.
- `{{#var}}...{{/var}}` renders when `var` is true, and once per item when it is
  a list. `{{^var}}...{{/var}}` renders when it is not.
- Every branch renders to valid YAML. The validator renders each combination of
  sections once.
- Every document is an object with `apiVersion` and `kind`.

### The chart

A package that ships a `chart/` directory installs it through a `HelmChart`
object. Edka installs the chart of the same version the template came from:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: {{{ namespace }}}
  name: {{{ release_name }}}
spec:
  chart: ./chart
  targetNamespace: {{{ namespace }}}
  valuesContent: |-
    fullnameOverride: "{{{ release_name }}}"
    image:
      repository: "ghcr.io/usememos/memos"
      tag: "{{{ image_tag }}}"
```

Rules for the chart:

- `Chart.yaml` has `apiVersion: v2` and `type: application`. Edka packs the
  chart with the slug as its `name` and the package version as its `version`,
  so a new version is raised in `template.yaml` alone.
- `values.yaml` exists and declares every key that `valuesContent` passes. A
  key the chart does not declare is reported, which catches typos.
- The `HelmChart` is named `{{{ release_name }}}`, and leaves out `spec.repo`,
  `spec.version` and `spec.chartContent`. Edka sets the source of the chart.
- Every Deployment, StatefulSet and DaemonSet carries the label
  `app.kubernetes.io/instance: {{ .Release.Name }}` on itself. Edka finds what
  the app runs by that label. Without it an install waits a minute before it
  reports done, and the app page shows no workloads.

A custom app can also install a chart from somewhere else, by naming it in
`spec.chart` and `spec.repo`. A community package installs only the chart
it ships.

### Secrets

A secret field is a `password` field, or any field with `secret: true`.

- A secret field has no `default`. A value Edka generates is declared with
  `generate: true`.
- A secret appears only inside a Secret: under `stringData` as `{{{ field }}}`,
  or under `data` as `{{{ field_base64 }}}`. It never appears in Helm values, a
  ConfigMap or an annotation.
- Each secret field is the whole value of one key of a Secret named after
  `{{{ release_name }}}`, in the namespace of the app:

  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    namespace: {{{ namespace }}}
    name: {{{ release_name }}}-config
  stringData:
    APP_SECRET: "{{{ app_secret }}}"
  ```

  That is where Edka reads the value back, so an edit or an update that leaves
  the field blank keeps the value the cluster has. A secret that only appears
  inside a longer value, such as a connection string, cannot be kept, and is
  rejected.
- The chart takes the name of that Secret as a value, such as `existingSecret`,
  and reads the keys with `envFrom` or `secretKeyRef`.
- A changed secret changes the Secret and nothing in the Helm release, so the
  pods keep the old value. Pass `{{{ secrets_checksum }}}` to the chart as a pod
  annotation, and the pods restart when a secret changes:

  ```yaml
  valuesContent: |-
    podAnnotations:
      checksum/secrets: "{{{ secrets_checksum }}}"
  ```

  The chart puts `podAnnotations` on its pod template. The value is keyed with
  a secret only Edka holds, so the secrets cannot be worked out from it. A
  package with secret fields that leaves it out gets the warning
  `chart.secrets-checksum`.
- A credential written into the template as plain text is reported.

The fields Edka fills from a database the installer selects, such as
`postgres_password` and `database_url`, are exempt from the one-key rule. Edka
reads them from the database at every render.

## Image updates

```yaml
auto_update:
  targets:
    - type: "image-tag"
      field: "image_tag"
      repository: "ghcr.io/usememos/memos"
      helm_value_path: "image.tag"
```

`field` names the field that holds the tag, and `helm_value_path` the value of
the chart it sets. With the standard auto-update fields in the form, Edka's
agent in the cluster moves the tag within the policy the installer chose. See
[platform-fields.md](platform-fields.md).

A package has no target for the chart version. The chart version is the
package version, and it changes when a new version is published.

## Endpoints and runtime selectors

```yaml
endpoints:
  - name: "Memos"
    type: "service"            # service | info | loadbalancer | url
    icon: "server"
    value_template: "http://{{{ release_name }}}.{{{ namespace }}}.svc.cluster.local:5230"
    description: "Address inside the cluster"
  - name: "External URL"
    type: "url"
    value_template: "https://{{{ hostname }}}"
    show_if: "access_enabled"

runtime_selectors:
  labels:
    edka.io/app-id: "{{{ app_id }}}"
  namespaces:
    - "{{{ namespace }}}"
  workloads:
    - "{{{ release_name }}}"
  services:
    - "{{{ release_name }}}"
```

## Versions and updates

- A published version never changes. A change to a package is a new version,
  with a higher number in `template.yaml`.
- An installed app stays on the version it was installed with. Publishing a
  version changes no installed app.
- An update moves one app to another version. A setting that still holds the
  default of the installed version takes the default of the new version, which
  is how a new image tag reaches the app. A setting that was changed keeps its
  value. A field the new version adds gets its default, and a field it drops
  is left out. A field with `editable: false` and the namespace never move.
- The stored secrets stay, and Edka generates the secrets the new version adds
  with `generate: true`.
- Before an update, Edka shows what the new version runs and creates that the
  installed one does not, and what the update does to the settings.

## `test/answers.yaml`

Answers to the form, by field name, for the fields that have no default. The
validator renders the template with the defaults and these answers.

```yaml
access_enabled: true
ingress_class: "eg"
hostname: "memos.example.com"
```

## Validation

One validator checks a package everywhere: `edka apps validate`, the console,
the MCP tool and the check on a pull request in this repository.

```bash
edka apps validate ./memos
```

Each finding has a code, a file, a line and a fix. The prefix of the code says
what the finding is about: `package`, `manifest`, `field`, `template`, `secret`,
`chart`, `endpoint`, `answers`, `auto-update`, and `community` for the listing
rules. An error blocks publishing. A warning does not. Some rules are warnings
for an organization's own package and errors for a community one: see
[Community listing](#community-listing).

The validator also reports what the package runs and creates: images, kinds of
objects, endpoints, storage, databases, secrets and add-ons. Edka shows that
report in the catalog and before an update.

## Community listing

```bash
edka apps validate ./memos --community
```

A community package meets every rule above, and these:

- **Rules that warn an organization.** For an organization's own package these
  are warnings. For a community package they are errors: a link that is not
  `https`, a chart without `values.yaml` or with a value it does not declare, a
  secret field written outside a Secret, a credential written into the template,
  and a file that is not part of a package. An organization's package is
  published without such a file.

- **Listing.** `upstream`, `maintainers`, `images`, `platforms`, a `README.md`
  and a `test/answers.yaml`.
- **Images.** Every image the package runs is listed in `images`, and so is the
  repository of every auto-update target. Every image is pinned to a tag and
  its digest, `0.25.1@sha256:...`: in the default of the image tag field, or in
  `chart/values.yaml` for an image the form does not offer. `latest` is not a
  pinned tag. The validator reads the images from `chart/values.yaml` with the
  values of the template laid over it, so name each image there as `image`, or
  as `image.repository` and `image.tag`.
- **One chart.** The template installs `./chart` and nothing else. The chart
  declares no dependencies and ships no subcharts and no
  CustomResourceDefinitions. Its templates do not use `lookup` or `tpl`, and
  every `kind:` is written out.
- **One namespace.** Every object is placed in `{{{ namespace }}}`. The
  template may create the `Namespace`, the `HelmChart` and `HTTPRoute` objects.
  The chart may create Deployment, StatefulSet, Job, CronJob, Service,
  ConfigMap, Secret, PersistentVolumeClaim, ServiceAccount, NetworkPolicy,
  HorizontalPodAutoscaler and PodDisruptionBudget objects.
- **The `HelmChart`.** Only `chart`, `targetNamespace`, `valuesContent`,
  `valuesSecrets` and `timeout` under `spec`.
- **Exposure.** Services are of type `ClusterIP`. A route takes its hostname
  from a field with `validation: "domain"` and points at a Service of the app.
- **Pods.** No host network, host PID, host IPC, `hostPath` volumes, host ports
  or privileged containers, and no added capabilities beyond the Kubernetes
  baseline.
- **Resources.** The form has `cpu_request`, `memory_request`, `cpu_limit` and
  `memory_limit`, with default limits of at most 4 cores and 8 Gi.
- **The form.** No fields that read agents or object storage credentials of the
  organization. Metrics name a metric and let Edka build the query.
- **Add-ons.** `required_addons` names add-ons Edka can install.
- **An install that can be tested.** The chart installs on an empty cluster
  with `chart/ci/test-values.yaml`, after `chart/ci/prerequisites.yaml` is
  applied when the package ships one. The checks of this repository install it
  that way, with the image tag the form pins.

These rules are checked before a package is listed. Nothing is checked when a
cluster installs it: a packaged app installs the way Edka's own apps do.
