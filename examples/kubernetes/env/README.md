# Values per environment
One file per chart and environment, `values.<chart>.<env>.yaml`, only the differences to the `values.yaml` of the chart.

| File | Content |
| --- | --- |
| `values.sample-api.dev.yaml` | sample-api in dev: release candidate tag, public host on staging certificates. |
| `values.sample-api.prod.yaml` | sample-api in prod: fixed release tag, three replicas, production certificates. |
