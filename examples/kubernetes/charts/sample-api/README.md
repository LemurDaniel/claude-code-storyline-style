# sample-api chart
One web API with a service, a deployment and an optional ingress.

```powershell
helm upgrade --install sample-api ./charts/sample-api --namespace sample-dev --create-namespace -f ./charts/sample-api/values.dev.yaml
```

| File | Content |
| --- | --- |
| `Chart.yaml` | Name and version of the chart. |
| `values.yaml` | Defaults for every environment, one section per area. |
| `values.dev.yaml` | Only the differences for dev: release candidate tag, public host on staging certificates. |
| `values.prod.yaml` | Only the differences for prod: fixed release tag, three replicas, production certificates. |
| `templates/_helpers.tpl` | Labels and image, defined once for every template. |
| `templates/service.yaml` | ClusterIP service in front of the pods. |
| `templates/deployment.yaml` | The pods: image, resources, probes and environment. |
| `templates/ingress.yaml` | Public host with TLS, only when `ingress.isEnabled` is set. |
