# sample-api chart
One web API with a service, a deployment and an optional ingress.
The values per environment live outside the chart, in `env/` next to `charts/`.

```powershell
helm upgrade --install sample-api ./charts/sample-api --namespace sample-dev --create-namespace -f ./env/values.sample-api.dev.yaml
```

| File | Content |
| --- | --- |
| `Chart.yaml` | Name and version of the chart. |
| `values.yaml` | Defaults for every environment, one section per area. |
| `templates/_helpers.tpl` | Labels and image, defined once for every template. |
| `templates/service.yaml` | ClusterIP service in front of the pods. |
| `templates/deployment.yaml` | The pods: image, resources, probes and environment. |
| `templates/ingress.yaml` | Public host with TLS, only when `ingress.isEnabled` is set. |
