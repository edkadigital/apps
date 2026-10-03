# Security

## Report a vulnerability

Report a vulnerability in a package, a chart or a check of this repository
privately, not in a public issue:

- **Report a vulnerability** under the Security tab of this repository, or
- an email to security@edka.io, encrypted with the
  [PGP key](https://edka.io/pgp-key.txt) if you want.

Name the package and its version, the steps that reproduce the problem and what
it lets an attacker do.

## Where a report goes

| The problem is in | Report it to |
|---|---|
| A package, a chart or a check of this repository | This repository, as above |
| The app a package installs, such as Gitea | The upstream project, named under `upstream.repository` in the `template.yaml` of the package |
| Edka: the console, the CLI or the API | security@edka.io |

## After a report

A fix to a package is a new version of it. Installed apps stay on their version
until someone updates them, and Edka shows what the update changes first.

A package with a security problem that is not fixed is withdrawn. It leaves the
catalog. Installed apps keep running, and their page says why the package was
withdrawn.
