{{- define "gitea.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "gitea.image" -}}
{{- $tag := .Values.image.tag | default (printf "%s-rootless" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{- define "gitea.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "gitea.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Rolls the pod when the configuration that is not secret changes. The chart
cannot read existingSecret, so a changed secret rolls the pod through
podAnnotations: pass a value there that changes with the Secret.
*/}}
{{- define "gitea.configChecksum" -}}
{{- toYaml .Values.config | sha256sum -}}
{{- end -}}

{{/*
Environment shared by the init container and the main container. The image's
entrypoint applies GITEA__* variables to app.ini via environment-to-ini on
every start, so both containers see identical configuration.
*/}}
{{- define "gitea.configEnv" -}}
- name: GITEA__security__INSTALL_LOCK
  value: "true"
{{- if .Values.service.ssh.enabled }}
- name: GITEA__server__START_SSH_SERVER
  value: "true"
- name: GITEA__server__SSH_LISTEN_PORT
  value: "2222"
- name: GITEA__server__SSH_PORT
  value: {{ .Values.service.ssh.port | quote }}
{{- else }}
- name: GITEA__server__DISABLE_SSH
  value: "true"
{{- end }}
{{- range $key, $value := .Values.config }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
