# Kubernetes examples
| File | Content |
| --- | --- |
| `cluster/issuer.letsencrypt.yaml` | Plain manifest for cluster-wide resources: two cert-manager issuers, one section each. |
| `env/` | Values per environment, one file per chart and environment, only the differences to the defaults of the chart. |
| `charts/sample-api/` | Helm chart of one web API, the defaults in `values.yaml`. |
