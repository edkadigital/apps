# Edka apps

Packages for the community catalog of [Edka](https://edka.io). Every package
under `apps/` installs from the catalog of an Edka cluster. Its chart also
installs with Helm on any Kubernetes cluster.

## What is here

```
apps/<slug>/            one package per app
  template.yaml         catalog entry, settings form, manifests
  chart/                the Helm chart the template installs
  README.md             what the app is, what it needs, where the facts come from
  icon.svg              optional
  test/answers.yaml     answers the checks fill the form with
spec/
  package-format.md     the package format
  platform-fields.md    the field names Edka acts on
skills/edka-app/        the skill an AI agent follows to write a package
checks/                 the checks that run on every pull request
```

[`apps/gitea`](apps/gitea) is the reference package.

The commands below use the [Edka CLI](https://edka.io/docs/cli/overview/).
They need an Edka account, signed in with `edka login`.

## Package an app for your organization

A package does not have to be public. Published to an organization, it is a
custom app. A custom app is private to that organization, appears under
**Custom Apps** in the console, and installs on its clusters like any other
app.

```bash
edka apps init memos --name "Memos" --image ghcr.io/usememos/memos --tag 0.25.1 --port 5230 --with access,storage
```

```bash
edka apps validate ./memos
```

```bash
edka apps publish ./memos
```

An AI agent does the same from the repository of an app. Copy
[`skills/edka-app`](skills/edka-app) into the skills directory of the agent,
such as `~/.claude/skills/` for Claude Code, and ask it to package the app. The
Edka MCP server offers the same steps as tools: `custom_app_init`,
`custom_app_validate`, `custom_app_publish` and `app_install`.

The format is in [`spec/package-format.md`](spec/package-format.md).

## Add an app to the community catalog

Write the package with your GitHub handle under `maintainers`, run the checks,
and offer it:

```bash
edka apps share apps/<slug>
```

The command opens a pull request from your GitHub account. A maintainer reads
the package and merges it, and a merged version appears in the catalog with a
following Edka release. [CONTRIBUTING.md](CONTRIBUTING.md) has the tools, the
checks and the steps.

## What a community package may do

The rules are in [Community listing](spec/package-format.md#community-listing).
In short, a community package:

- installs one chart, the one it ships, into one namespace
- runs only the images it lists, each pinned to a tag and its digest
- creates workloads, Services, ConfigMaps, Secrets, volume claims and routes,
  and nothing at the level of the cluster
- runs pods within the baseline Pod Security Standard
- names where the app comes from, its license and who maintains the package

## Versions

A listed version never changes. A change to a package is a new version, with a
higher `version` in `template.yaml` and `chart/Chart.yaml`. An installed app
stays on the version it was installed with until someone updates it, and Edka
shows what the new version runs and creates before the update.

## Withdrawn packages

A package with a security problem that is not fixed, or one that nobody
maintains, is withdrawn. It leaves the catalog. Installed apps keep running,
and their page says why the package was withdrawn.

## Report a problem

- A problem with a package: [open an issue](https://github.com/edkadigital/apps/issues/new/choose)
  and name the package and its version.
- A vulnerability: report it privately, as [SECURITY.md](SECURITY.md)
  describes.

## License

Apache-2.0. See [LICENSE](LICENSE). Each app keeps its own license, named under
`upstream.license` in its `template.yaml`.
