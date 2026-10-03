## What this adds or changes

<!-- The app, its upstream repository and the version of the package. -->

## Checklist

- [ ] One app, and only files under `apps/<slug>/`
- [ ] `edka apps validate apps/<slug> --community` reports no findings
- [ ] `checks/chart.sh apps/<slug>` passes
- [ ] `checks/smoke.sh apps/<slug> <context>` passes on a fresh cluster
- [ ] The README names the source of each fact about the app
- [ ] Every image is pinned to a tag and its digest, read from the registry
- [ ] For a new package: my GitHub handle is under `maintainers`
- [ ] For a change to a package on `main`: `version` is higher in `template.yaml` and `chart/Chart.yaml`
