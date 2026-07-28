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
*/}}
{{- define "infrakitchen.image" -}}
{{- $image := .Values.backend.image -}}
{{- $registry := default $image.registry .Values.global.imageRegistry -}}
{{- $tag := default .Values.global.imageTag $image.tag -}}
{{- if $image.digest -}}
{{- if $registry -}}
{{- printf "%s/%s@%s" $registry $image.repository $image.digest -}}
{{- else -}}
{{- printf "%s@%s" $image.repository $image.digest -}}
{{- end -}}
{{- else -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $image.repository (required "The image tag is required" (toString $tag)) -}}
{{- else -}}
{{- printf "%s:%s" $image.repository (required "The image tag is required" (toString $tag)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return pod image pull secrets in PodSpec form.
*/}}
{{- define "infrakitchen.renderImagePullSecrets" -}}
{{- $imagePullSecrets := .Values.backend.image.pullSecrets | default list -}}
{{- $globalPullSecrets := .Values.global.imagePullSecrets | default list -}}
{{- $pullSecrets := concat $imagePullSecrets $globalPullSecrets -}}
{{- if $pullSecrets }}
imagePullSecrets:
{{- range $pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
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
Return the fullname used by a dependency.
*/}}
{{- define "infrakitchen.dependency.fullname" -}}
{{- $chartName := .chartName -}}
{{- $chartValues := .chartValues | default dict -}}
{{- $alias := get $chartValues "nameOverride" -}}
{{- $dependencyName := default $chartName $alias -}}
{{- if hasKey $chartValues "fullnameOverride" -}}
{{- $override := get $chartValues "fullnameOverride" -}}
{{- if $override -}}
{{- $override | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $dependencyName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $dependencyName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the network policy API version for the target cluster.
*/}}
{{- define "infrakitchen.capabilities.networkPolicy.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1/NetworkPolicy" -}}
networking.k8s.io/v1
{{- else -}}
extensions/v1beta1
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


{{/*
Return the RabbitMQ URI
*/}}
{{- define "infrakitchen.rabbitmq.uri" -}}
{{- if .Values.rabbitmq.external.enabled -}}
{{- if .Values.rabbitmq.external.uri -}}
{{- .Values.rabbitmq.external.uri -}}
{{- else -}}
{{- $host := required "rabbitmq.external.host is required when rabbitmq.external.enabled is true and rabbitmq.external.uri is not set" .Values.rabbitmq.external.host -}}
{{- $port := default 5672 .Values.rabbitmq.external.port -}}
{{- printf "amqp://$(RABBITMQ_USERNAME):$(RABBITMQ_PASSWORD)@%s:%v/" $host $port -}}
{{- end -}}
{{- else -}}
{{- printf "amqp://$(RABBITMQ_USERNAME):$(RABBITMQ_PASSWORD)@%s:5672/" (include "infrakitchen.rabbitmq.serviceName" .) -}}
{{- end -}}
{{- end -}}


{{/*
Return the managed RabbitMQ cluster name.
*/}}
{{- define "infrakitchen.rabbitmq.clusterName" -}}
{{- default (printf "%s-rabbitmq" (include "infrakitchen.fullname" .)) .Values.rabbitmq.cluster.name -}}
{{- end -}}


{{/*
Return the RabbitMQ service name used by applications.
*/}}
{{- define "infrakitchen.rabbitmq.serviceName" -}}
{{- include "infrakitchen.rabbitmq.clusterName" . -}}
{{- end -}}


{{/*
Return the RabbitMQ credentials secret name.
*/}}
{{- define "infrakitchen.rabbitmq.secretName" -}}
{{- if .Values.rabbitmq.external.enabled -}}
{{- required "rabbitmq.external.existingSecret is required when rabbitmq.external.enabled is true and rabbitmq.external.uri is not set" .Values.rabbitmq.external.existingSecret -}}
{{- else if .Values.rabbitmq.auth.existingSecret -}}
{{- .Values.rabbitmq.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-default-user" (include "infrakitchen.rabbitmq.clusterName" .) -}}
{{- end -}}
{{- end -}}
