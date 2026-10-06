{{/*
Expand a value through tpl when needed and render maps/lists as YAML.
*/}}
{{- define "infrakitchen.tplvalues.render" -}}
{{- $value := .value -}}
{{- $context := .context -}}
{{- if kindIs "string" $value -}}
{{- tpl $value $context -}}
{{- else -}}
{{- tpl (toYaml $value) $context -}}
{{- end -}}
{{- end -}}

{{/*
Return the chart name.
*/}}
{{- define "infrakitchen.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the release fullname.
*/}}
{{- define "infrakitchen.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "infrakitchen.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return selector labels used by chart-managed workloads.
*/}}
{{- define "infrakitchen.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "infrakitchen.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Return standard object labels.
*/}}
{{- define "infrakitchen.labels.standard" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "infrakitchen.labels.matchLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/*
Return the proper image name.
Usage: {{ include "infrakitchen.image" (dict "image" .Values.backend.image "context" $) }}
*/}}
{{- define "infrakitchen.image" -}}
{{- $image := .image -}}
{{- $ctx := .context -}}
{{- $registry := default $image.registry $ctx.Values.global.imageRegistry -}}
{{- $repository := required "image.repository is required" $image.repository -}}
{{- $prefix := ternary (printf "%s/%s" $registry $repository) $repository (not (empty $registry)) -}}
{{- if $image.digest -}}
{{- printf "%s@%s" $prefix $image.digest -}}
{{- else -}}
{{- $tag := $image.tag | default $ctx.Values.global.imageTag | default $ctx.Chart.AppVersion -}}
{{- printf "%s:%s" $prefix (required "An image tag is required (image.tag, global.imageTag or Chart appVersion)" (toString $tag)) -}}
{{- end -}}
{{- end -}}

{{/*
Return pod image pull secrets in PodSpec form.
Usage: {{ include "infrakitchen.renderImagePullSecrets" (dict "image" .Values.backend.image "context" $) }}
*/}}
{{- define "infrakitchen.renderImagePullSecrets" -}}
{{- $pullSecrets := concat (.image.pullSecrets | default list) (.context.Values.global.imagePullSecrets | default list) | uniq -}}
{{- if $pullSecrets }}
imagePullSecrets:
{{- range $pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Return metadata labels and annotations for a chart object.
Usage: {{ include "infrakitchen.metadata" (dict "component" "infrakitchen" "labels" .Values.x.labels "annotations" .Values.x.annotations "context" $) }}
*/}}
{{- define "infrakitchen.metadata" -}}
{{- $ctx := .context -}}
namespace: {{ $ctx.Release.Namespace | quote }}
labels:
  {{- include "infrakitchen.labels.standard" $ctx | nindent 2 }}
  {{- if .component }}
  app.kubernetes.io/component: {{ .component }}
  {{- end }}
  {{- with $ctx.Values.commonLabels }}
  {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 2 }}
  {{- end }}
  {{- with .labels }}
  {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 2 }}
  {{- end }}
{{- $annotations := merge (dict) (.annotations | default dict) ($ctx.Values.commonAnnotations | default dict) }}
{{- if $annotations }}
annotations:
  {{- include "infrakitchen.tplvalues.render" (dict "value" $annotations "context" $ctx) | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Return the name of the Secret holding jwt-secret and enc-secret.
*/}}
{{- define "infrakitchen.secretName" -}}
{{- default (printf "%s-secrets" (include "infrakitchen.fullname" .)) .Values.secretName -}}
{{- end -}}

{{/*
Return environment variables shared by all InfraKitchen containers.
*/}}
{{- define "infrakitchen.commonEnv" -}}
- name: POSTGRES_HOST
  value: {{ include "infrakitchen.database.hostname" . | quote }}
- name: POSTGRES_PORT
  value: {{ include "infrakitchen.database.port" . | quote }}
- name: POSTGRES_USER
  value: {{ .Values.database.user | quote }}
- name: POSTGRES_DB
  value: {{ .Values.database.name | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "infrakitchen.database.secretName" . }}
      key: {{ include "infrakitchen.database.secretKey" . }}
- name: JWT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "infrakitchen.secretName" . }}
      key: jwt-secret
- name: ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "infrakitchen.secretName" . }}
      key: enc-secret
{{- end -}}

{{/*
Return backend-only environment variables.
*/}}
{{- define "infrakitchen.backendEnv" -}}
- name: POSTGRES_MIGRATIONS
  value: {{ .Values.database.applyMigrations | quote }}
- name: MCP_ENABLED
  value: {{ .Values.mcp.enabled | quote }}
{{- end -}}

{{/*
Return the demo fixtures init container.
*/}}
{{- define "infrakitchen.demoInitContainer" -}}
- name: demo-fixtures
  image: {{ include "infrakitchen.image" (dict "image" .Values.backend.image "context" .) }}
  imagePullPolicy: {{ .Values.backend.image.pullPolicy | quote }}
  {{- with .Values.backend.containerSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  command:
    - /bin/sh
    - -c
    - PYTHONPATH=/app /app/.venv/bin/python /app/fixtures/generate_entities.py
  env:
    {{- include "infrakitchen.commonEnv" . | nindent 4 }}
{{- end -}}

{{/*
Render an InfraKitchen Deployment.
Params:
  context        - root context ($)
  values         - workload values (.Values.backend / .Values.worker / .Values.scheduler)
  name           - resource name
  component      - app.kubernetes.io/component label
  containerName  - main container name
  extraEnv       - optional YAML string of extra env entries rendered before values.extraEnvVars
  initContainers - optional YAML string of chart-managed init containers
*/}}
{{- define "infrakitchen.workload" -}}
{{- $ctx := .context -}}
{{- $v := .values -}}
{{- $imageArgs := dict "image" $v.image "context" $ctx -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  {{- include "infrakitchen.metadata" (dict "component" .component "annotations" $v.annotations "context" $ctx) | nindent 2 }}
spec:
  replicas: {{ $v.replicas }}
  revisionHistoryLimit: {{ $v.revisionHistoryLimit }}
  {{- with $v.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "infrakitchen.labels.matchLabels" $ctx | nindent 6 }}
      app.kubernetes.io/component: {{ .component }}
  template:
    metadata:
      labels:
        {{- include "infrakitchen.labels.standard" $ctx | nindent 8 }}
        app.kubernetes.io/component: {{ .component }}
        {{- with $v.podLabels }}
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
        {{- end }}
      {{- with $v.podAnnotations }}
      annotations:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
    spec:
      serviceAccountName: {{ include "infrakitchen.serviceAccountName" $ctx }}
      automountServiceAccountToken: {{ $v.automountServiceAccountToken }}
      {{- include "infrakitchen.renderImagePullSecrets" $imageArgs | nindent 6 }}
      {{- with $v.priorityClassName }}
      priorityClassName: {{ . | quote }}
      {{- end }}
      {{- if not (kindIs "invalid" $v.terminationGracePeriodSeconds) }}
      terminationGracePeriodSeconds: {{ $v.terminationGracePeriodSeconds }}
      {{- end }}
      {{- with $v.podSecurityContext }}
      securityContext:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
      {{- with $v.affinity }}
      affinity:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
      {{- with $v.nodeSelector }}
      nodeSelector:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
      {{- with $v.tolerations }}
      tolerations:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
      {{- with $v.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
      {{- if or .initContainers $v.initContainers }}
      initContainers:
        {{- with .initContainers }}
        {{- . | nindent 8 }}
        {{- end }}
        {{- with $v.initContainers }}
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
        {{- end }}
      {{- end }}
      containers:
        - name: {{ .containerName }}
          image: {{ include "infrakitchen.image" $imageArgs }}
          imagePullPolicy: {{ $v.image.pullPolicy | quote }}
          {{- with $v.containerSecurityContext }}
          securityContext:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.command }}
          command:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.args }}
          args:
            {{- range . }}
            - {{ . | quote }}
            {{- end }}
          {{- end }}
          env:
            {{- include "infrakitchen.commonEnv" $ctx | nindent 12 }}
            {{- with .extraEnv }}
            {{- . | nindent 12 }}
            {{- end }}
            {{- with $v.extraEnvVars }}
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
            {{- end }}
          {{- with $v.extraEnvVarsFrom }}
          envFrom:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          ports:
            - name: backend
              containerPort: {{ $v.containerPorts.backend }}
              protocol: TCP
          {{- with $v.resources }}
          resources:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.startupProbe }}
          startupProbe:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.readinessProbe }}
          readinessProbe:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.livenessProbe }}
          livenessProbe:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
          {{- with $v.extraVolumeMounts }}
          volumeMounts:
            {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 12 }}
          {{- end }}
        {{- with $v.extraContainers }}
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
        {{- end }}
      {{- with $v.extraVolumes }}
      volumes:
        {{- include "infrakitchen.tplvalues.render" (dict "value" . "context" $ctx) | nindent 8 }}
      {{- end }}
{{- end -}}

{{/*
Create the name of the service account to use.
*/}}
{{- define "infrakitchen.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "infrakitchen.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the CNPG cluster name.
*/}}
{{- define "infrakitchen.database.clusterName" -}}
{{- default (printf "%s-db" (include "infrakitchen.fullname" .)) .Values.cnpg.cluster.name -}}
{{- end -}}


{{/*
Return the Postgres Database Hostname.
*/}}
{{- define "infrakitchen.database.hostname" -}}
{{- if .Values.database.external.enabled -}}
{{- required "database.external.host is required when database.external.enabled is true" .Values.database.external.host -}}
{{- else -}}
{{- printf "%s-rw" (include "infrakitchen.database.clusterName" .) -}}
{{- end -}}
{{- end -}}


{{/*
Return the Postgres Database Port.
*/}}
{{- define "infrakitchen.database.port" -}}
{{- .Values.database.port | toString -}}
{{- end -}}


{{/*
Return the Postgres Database Secret Name.
*/}}
{{- define "infrakitchen.database.secretName" -}}
{{- if .Values.database.external.enabled -}}
{{- required "database.external.existingSecret is required when database.external.enabled is true" .Values.database.external.existingSecret -}}
{{- else if .Values.cnpg.bootstrap.existingSecret -}}
{{- .Values.cnpg.bootstrap.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "infrakitchen.database.clusterName" .) -}}
{{- end -}}
{{- end -}}


{{/*
Return the Postgres database secret key to retrieve credentials for database.
*/}}
{{- define "infrakitchen.database.secretKey" -}}
{{- if .Values.database.external.enabled -}}
{{- .Values.database.external.passwordKey -}}
{{- else -}}
{{- default "password" .Values.database.passwordKey -}}
{{- end -}}
{{- end -}}

