# Deprecated — dashboards are applied by CI, not by agents

See `.github/workflows/release.yml`. On `git tag v*.*.*`, the pipeline stamps the tag into every `dtctl/*.yaml` and applies the manifests. Agents never run `dtctl apply` in prod in this repo.
