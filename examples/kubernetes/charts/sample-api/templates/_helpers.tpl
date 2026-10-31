{{/*
  Labels shared by metadata, selector and pod template.
  Defined once, so the selector of the service always matches the pods.

  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
*/}}
{{- define "sample-api.labels" -}}
application: {{ .Values.application }}
microservice: {{ .Chart.Name }}
{{- end }}

{{/*
  The image with its fixed tag. Fails the render on a missing tag or on latest,
  so a pod restart never pulls a different version.

  image: {{ include "sample-api.image" . }}
*/}}
{{- define "sample-api.image" -}}
{{- $tag := required "image.tag must be a fixed version, set it in values.<env>.yaml." .Values.image.tag -}}
{{- if eq $tag "latest" -}}
{{- fail "image.tag must be a fixed version, got latest." -}}
{{- end -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}
