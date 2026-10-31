# Code Style: Kubernetes Manifests / Helm
- 2 spaces. Every app is a Helm chart under `charts/<app>/`. Plain manifests only for cluster-wide resources that are applied once (issuers, namespaces, storage classes).
  ```
  k8s/
    README.md
    issuer.letsencrypt.yaml
    charts/
      sample-api/
        Chart.yaml
        README.md
        values.yaml
        values.dev.yaml
        values.prod.yaml
        templates/
          _helpers.tpl
          deployment.yaml
          service.yaml
          ingress.yaml
  ```
- **File names with the kind first** per `SKILL.md` → "Structure": plain manifests as `<kind>.<topic>.yaml` (`issuer.letsencrypt.yaml`, `namespace.sample.yaml`). In a chart one app owns all templates, so the kind alone is the name (`deployment.yaml`, `service.yaml`). Values per environment as `values.<env>.yaml`.
- **One chart, values per environment:** `values.yaml` holds the defaults for every environment, `values.<env>.yaml` only the differences. The templates are the same for all environments, see `SKILL.md` → "Configuration separate from code".
  ```yaml
  # values.prod.yaml
  image:
    tag: "1.4.1"

  replicas: 3
  environment: Production
  ```
  Not like this: a full copy of every manifest in `prod/` and `test/`, every change has to be made twice.
- **Header as a section banner** at the top of every plain manifest, `Chart.yaml` and values file, like in YAML pipelines: what it holds, prerequisites, the install command. Templates have no header, the chart `README.md` lists them.
  ```yaml
  # ---------------------------------------------------------------------------
  # Certificate Issuers
  #
  #   Two cluster-wide ACME issuers for cert-manager.
  #   Requires: cert-manager and the nginx ingress controller in the cluster.
  #
  #   kubectl apply -f issuer.letsencrypt.yaml
  #
  ```
- **Several resources in one file** are separated by `---` and one section banner each, the title says what the resource is for.
  ```yaml
  ---
  # ---------------------------------------------------------------------------
  # Production - trusted certificates, switch over once staging works
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  ```
- **Values documented at the value**, one section per area (Image, Runtime, Service, Ingress), `(Required)`/`(Optional)` and the default in the comment above.
  ```yaml
  # ---------------------------------------------------------------------------
  # Runtime

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
  {{- $tag := required "image.tag must be a fixed version, set it in values.<env>.yaml." .Values.image.tag -}}
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
- **Templates:** `include` with `nindent` instead of `template`, `{{-` to trim whitespace, `required` with a message that states the expectation for every value without a sensible default.
  ```yaml
  - host: {{ required "ingress.host must be set when ingress.isEnabled is true." .Values.ingress.host }}
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": `helm lint` and `helm template` per `values.<env>.yaml`, the rendered output and every plain manifest through `kubeconform`.
  ```
  helm lint charts/sample-api -f charts/sample-api/values.dev.yaml
  helm template sample-api charts/sample-api -f charts/sample-api/values.dev.yaml | kubeconform -strict -ignore-missing-schemas
  ```
