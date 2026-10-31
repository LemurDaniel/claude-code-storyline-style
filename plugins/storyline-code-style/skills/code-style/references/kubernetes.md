# Code Style: Kubernetes Manifests / Helm
- 2 spaces. Every app is a Helm chart under `charts/<app>/`. Plain manifests only for cluster-wide resources that are applied once (issuers, namespaces, storage classes), on their own shelf `cluster/`. The root holds only shelves: `cluster/`, `env/`, `charts/`.
  ```
  README.md
  cluster/
    issuer.letsencrypt.yaml
  env/
    README.md
    values.sample-api.dev.yaml
    values.sample-api.prod.yaml
  charts/
    sample-api/
      Chart.yaml
      README.md
      values.yaml
      templates/
        _helpers.tpl
        deployment.yaml
        service.yaml
        ingress.yaml
  ```
- **File names with the kind first** per `SKILL.md` → "Structure": plain manifests as `<kind>.<topic>.yaml` (`issuer.letsencrypt.yaml`, `namespace.sample.yaml`). In a chart one app owns all templates, so the kind alone is the name (`deployment.yaml`, `service.yaml`). Values per environment as `values.<chart>.<env>.yaml`.
- **One chart, values per environment outside the chart:** `values.yaml` in the chart holds the defaults for every environment, `env/values.<chart>.<env>.yaml` next to `charts/` only the differences. The templates are the same for all environments, see `SKILL.md` → "Configuration separate from code". The chart never names an environment or a path outside itself, so `helm package` ships no environment and a config change needs no new chart version.
  ```yaml
  # env/values.sample-api.prod.yaml
  image:
    tag: "1.4.1"

  replicas: 3
  environment: Production
  ```
  Not like this: a full copy of every manifest in `prod/` and `test/`, every change has to be made twice. Nor `values.prod.yaml` inside the chart, it ships with every package of the chart.
- **Header as a section banner** at the top of every plain manifest, `Chart.yaml` and values file, like in YAML pipelines: what it holds, prerequisites, the install command. Templates have no header, the chart `README.md` lists them.
  ```yaml
  # ---------------------------------------------------------------------------
  # Certificate Issuers
  #   Two cluster-wide ACME issuers for cert-manager.
  #   Requires: cert-manager and the nginx ingress controller in the cluster.
  #
  #   kubectl apply -f cluster/issuer.letsencrypt.yaml
  # ---------------------------------------------------------------------------
  ```
- **Several resources in one file** are separated by `---` and one section banner each inside a chapter, the title says what the resource is for.
  ```yaml
  ---
  # ---------------------------------------------------------------------------
  # Production
  #   Trusted certificates, switch over once staging works.
  # ---------------------------------------------------------------------------
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  ```
- **Values documented at the value**, one section per area (Image, Runtime, Service, Ingress), `(Required)`/`(Optional)` and the default in the comment above.
  ```yaml
  # ---------------------------------------------------------------------------
  # Runtime
  #   Replicas, environment and resources of the pods.
  # ---------------------------------------------------------------------------
  # (Optional) Number of pods. Defaults to 1.
  replicas: 1
  ```
- **Labels defined once:** a `define` in `_helpers.tpl` feeds metadata, selector and pod template, so the selector always matches the pods. Labels are `application` (the whole platform) and `microservice` (this chart). In a plain manifest a YAML anchor does the same (`labels: &selectorLabels` and `matchLabels: *selectorLabels`).
  ```yaml
  selector:
    matchLabels:
      {{- include "sample-api.labels" . | nindent 6 }}
  ```
- **A fixed image tag, never `latest`:** the tag is set per environment and the template fails the render without one. With a fixed tag `imagePullPolicy: IfNotPresent` is enough.
  ```yaml
  {{- $tag := required "image.tag must be a fixed version, set it in the values of the environment." .Values.image.tag -}}
  {{- if eq $tag "latest" -}}
  {{- fail "image.tag must be a fixed version, got latest." -}}
  {{- end -}}
  ```
  Not like this: `image: registry.example.com/sample-api:latest` with `imagePullPolicy: Always` and the real version as a comment. Every pod restart can pull a different version.
- **Fixed order in metadata:** `namespace`, `name`, `labels`, `annotations`. In the container: `name`, `image`, `imagePullPolicy`, then resources → ports → probes → env, each block under a group comment and set apart by an empty line.
  ```yaml
  - name: {{ .Chart.Name }}
    image: {{ include "sample-api.image" . }}
    imagePullPolicy: IfNotPresent

    # Resources
    resources:
      {{- toYaml .Values.resources | nindent 6 }}

    # Ports
    ports:
      - name: http
        containerPort: {{ .Values.service.targetPort }}
  ```
- Every container has `requests` and `limits` and a readiness probe, a liveness probe where a hung process does not recover on its own.
- **Other services by their cluster DNS name**, never by IP. The names live in the values, the template builds the addresses.
  ```yaml
  # Other services, one base address per entry in values.yaml -> dependencies
  {{- range $name, $service := .Values.dependencies }}
  - name: {{ $name }}__BaseAddress
    value: http://{{ $service }}.{{ $.Release.Namespace }}.svc.cluster.local
  {{- end }}
  ```
- **Annotations grouped by topic**, one group comment each, the groups set apart by an empty line. Numbers and booleans in annotations and `env` are quoted strings (`"true"`, `"600"`).
  ```yaml
  annotations:
    # TLS - certificate from the ClusterIssuer, plain HTTP is redirected
    cert-manager.io/cluster-issuer: {{ .Values.ingress.clusterIssuer }}
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

    # Uploads - large bodies and long requests for file imports
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  ```
- **`include` with `nindent`, never `template`:** `include` returns a string that can be piped, `nindent` starts a new line and indents the block to where it belongs.
  ```yaml
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
  ```
  Not like this: `{{ template "sample-api.labels" . }}`, its output cannot be piped or indented, so the YAML breaks as soon as the block sits deeper.
- **`{{-` and `-}}` trim the whitespace** before and after a tag, so `if`, `range` and `define` leave no empty lines or broken indents in the rendered output.
  ```yaml
  {{- if .Values.ingress.isEnabled }}
  ```
- **`required` for every value without a sensible default** (host, image tag), the message states when and why it is needed. Without it Helm renders an empty value that only fails in the cluster. A value with a sensible default goes into `values.yaml` instead.
  ```yaml
  - host: {{ required "ingress.host must be set when ingress.isEnabled is true." .Values.ingress.host }}
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": `helm lint` and `helm template` per `env/values.<chart>.<env>.yaml`, the rendered output and every plain manifest through `kubeconform`.
  ```
  helm lint charts/sample-api -f env/values.sample-api.dev.yaml
  helm template sample-api charts/sample-api -f env/values.sample-api.dev.yaml | kubeconform -strict -ignore-missing-schemas
  ```
