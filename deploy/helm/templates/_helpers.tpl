{{/*
Standard labels applied to every resource in this chart.
*/}}
{{- define "checkout.labels" -}}
app: checkout
owner: observe-and-resolve
episode: "09"
app.kubernetes.io/managed-by: argocd
app.kubernetes.io/version: {{ .Values.appVersion | quote }}
{{- end }}
