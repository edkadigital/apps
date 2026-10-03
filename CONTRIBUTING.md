# Contributing

A contribution to this repository is a package: one app per pull request, and
only files under `apps/<slug>/`. For a change to the checks, the workflows, the
spec or the skill, open an issue first.

## What you need

- An Edka account and the [Edka CLI](https://edka.io/docs/cli/overview/),
  signed in with `edka login`. Every `edka apps` command needs it.
- `helm` 3, `yq`, `jq`, `kubeconform` and `docker` for `checks/chart.sh`. It
  uses Docker to read image digests from their registries.
- `kubectl`, `helm`, `yq` and a cluster that can be thrown away for
  `checks/smoke.sh`, such as one made with [kind](https://kind.sigs.k8s.io).
- The [GitHub CLI](https://cli.github.com), signed in to your account, for
  `edka apps share`.

## Write the package

[`skills/edka-app/SKILL.md`](skills/edka-app/SKILL.md) has the steps, for a
person or an AI agent. The format is in
[`spec/package-format.md`](spec/package-format.md) and
[`spec/platform-fields.md`](spec/platform-fields.md).
[`apps/gitea`](apps/gitea) is the reference package.

- Take every fact about the app from its upstream sources: the image, the
  port, the paths, the environment variables, the license. The README of the
  package names the source of each one, with links.
- Pin every image to a tag and its digest. Read the digest from the registry:

  ```bash
  docker buildx imagetools inspect <repository>:<tag>
  ```

- List your GitHub handle under `maintainers`. A new package comes from one of
  its maintainers.
- Keep credentials out of every file. The values the checks need go into
  `chart/ci/prerequisites.yaml`, made up for the test.
- Keep the chart small: no bundled database, no Ingress, no monitoring stack,
  no subcharts, no CustomResourceDefinitions.

## Test files of a chart

| File | Purpose |
|---|---|
| `chart/ci/test-values.yaml` | Values the checks lint, render and install with. The install has to work on an empty cluster, so use an embedded database such as SQLite when the app has one. |
| `chart/ci/prerequisites.yaml` | Objects the checks apply before the install: the Secret the chart reads, and a throwaway database when the app cannot run without one. |
| `test/answers.yaml` | Answers to the form fields that have no default, by field name. |

The checks install the image tag the form pins. They read it from the
`auto_update` target of `template.yaml` and the default of the field it names.

## Run the checks

Run them in this order. Each one prints what to fix.

```bash
edka apps validate apps/<slug> --community
```

```bash
checks/chart.sh apps/<slug>
```

```bash
kind create cluster --name edka-apps
```

```bash
checks/smoke.sh apps/<slug> kind-edka-apps
```

`checks/smoke.sh` installs on the kubectl context its second argument names,
never on the current one. `KEEP=1` leaves the namespace in place after the
install.

## Open the pull request

```bash
edka apps share apps/<slug>
```

The command checks the package again, asks for confirmation and opens a pull
request from your GitHub account. A pull request opened by hand works the same
way.

These checks run on the pull request:

| Check | What it does |
|---|---|
| Chart | Lints the chart, renders it, validates the result against the Kubernetes schemas and applies the community rules to it. Confirms that each pinned tag still points at its digest and that the image is published for the listed platforms. Confirms that a changed package has a higher version, and that a new package comes from one of its maintainers. |
| Install | Installs the chart on a fresh cluster, in a namespace that enforces the baseline Pod Security Standard, and waits for it to become ready. |

A maintainer runs `edka apps validate --community` on the package again, reads
it and merges it. A merged version appears in the catalog with a following
Edka release.

## Change a package

A listed version never changes. A change to a package on `main` raises
`version` in `template.yaml` and in `chart/Chart.yaml`. The skill has the steps
for
[moving a package to a new release of the app](skills/edka-app/SKILL.md#moving-a-package-to-a-new-release-of-the-app).

## License

A contribution is licensed under Apache-2.0, as section 5 of the
[LICENSE](LICENSE) states. The app a package installs keeps its own license,
named under `upstream.license` in `template.yaml`.
