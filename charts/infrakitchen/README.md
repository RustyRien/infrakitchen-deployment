# InfraKitchen Helm Chart

Deploys the [InfraKitchen](https://github.com/electrolux-oss/infrakitchen) backend, worker and scheduler, backed by PostgreSQL.
Requires Kubernetes 1.30+.

## Workloads

The chart renders three Deployments from the same image: `backend` (API, UI and migrations), `worker` and `scheduler`.
Each one has its own block in `values.yaml` with the same set of options (image, resources, probes, security contexts, scheduling, extra env/volumes/containers).

- The image tag defaults to the chart `appVersion`. Override it for all workloads with `global.imageTag`, or per workload with `<workload>.image.tag`.
- The scheduler uses the `Recreate` strategy so two schedulers never run at the same time during a rollout.
- `backend.pdb.enabled=true` adds a PodDisruptionBudget for the backend.

## Security defaults

Pods run as the image's non-root `infrakitchen` user (UID/GID 1000) with the `RuntimeDefault` seccomp profile.
Containers drop all capabilities and disallow privilege escalation, and the ServiceAccount token is not mounted (except for backend and scheduler when `workerOnDemand.enabled=true`).
`readOnlyRootFilesystem` is not enabled because nginx, OpenTofu and git write to the image filesystem.
Override `<workload>.podSecurityContext` and `<workload>.containerSecurityContext` if your platform needs different settings.

## On-demand workers

Set `workerOnDemand.enabled=true` to let the scheduler spawn worker Pods from worker templates (see `examples/ondemand-workers.yaml`). The chart then:

- creates the ServiceAccount and a Role/RoleBinding (`pods` get/list/create/delete, `pods/log` get, `secrets`/`configmaps` list) in the release namespace and every namespace in `workerOnDemand.rbac.extraNamespaces`;
- mounts the ServiceAccount token into the backend and scheduler (the static worker does not get it);
- sets `POD_NAME` (downward API) and `WORKER_AUTOSCALER_INTERVAL_SECONDS`, `WORKER_START_TIMEOUT_SECONDS`, `WORKER_FAILED_RETENTION_SECONDS` on backend and scheduler.

Spawned Pods inherit the image and env (including Secret references) of the InfraKitchen container, so Secrets and ConfigMaps must also exist in any extra namespace.
Their resources come from the worker template manifest in InfraKitchen (default 500m/512Mi requests), not from this chart.

## OpenTofu plugin cache

`tofuCache.enabled` (default `true`) sets `TF_PLUGIN_CACHE_ENABLED`; `tofuCache.dir` optionally sets `TF_PLUGIN_CACHE_DIR`.
By default the cache lives in the container's temp dir, so it is lost on restart and not shared. Mount a volume there via `<workload>.extraVolumes`/`extraVolumeMounts` to persist it; keep it on local disk, not a network share.

## PostgreSQL

This chart manages a CloudNativePG `Cluster` by default.

- Install the CloudNativePG operator and CRDs before installing this chart.
- InfraKitchen connects to the CNPG primary read-write service at `<cluster-name>-rw`.
- If `cnpg.bootstrap.existingSecret` is not set, this chart creates a bootstrap Secret for CNPG and uses it for the application password.

### Managed CNPG

Set `cnpg.bootstrap.password` on first install. After the CNPG bootstrap Secret exists, later upgrades reuse the stored password and do not require `cnpg.bootstrap.password` again.

### External PostgreSQL

Set:

- `database.external.enabled=true`
- `database.external.host`
- `database.external.existingSecret`
- optionally `database.external.passwordKey`

In external mode, this chart does not render CNPG resources.

## Secrets

This chart auto-generates `jwt-secret`, but `enc-secret` must be provided as a Fernet key on first install. After the Secret exists, later upgrades reuse the stored value and do not require `secrets.encSecret` again.

Generate a Fernet key:

```bash
python3 -c 'import base64; from cryptography.fernet import Fernet; key = Fernet.generate_key().decode(); print(base64.urlsafe_b64encode(key.encode()).decode())'

```

or use `MWhVVmYtQ3dFNDc3ODdrTEJ1TUx4cUpLcm1ZTFQ4TlRsZlY0RnpMV0owVT0=` for testing purposes.

Pass it during install or upgrade:

```bash
helm upgrade --install infrakitchen ./charts/infrakitchen \
  --set secrets.encSecret='PASTE_FERNET_KEY_HERE'
```

Or set it in your values file:

```yaml
secrets:
  encSecret: "PASTE_FERNET_KEY_HERE"
```

If `secretName` is set, the referenced Kubernetes Secret must already contain both `jwt-secret` and `enc-secret`.

### GitOps (Argo CD, Flux) and `helm template`

Reusing stored secrets relies on Helm `lookup`, which returns nothing under `helm template` and most GitOps tools.
There, `jwt-secret` would be regenerated on every render and `secrets.encSecret`/`cnpg.bootstrap.password` would be required every time.
For these setups, create the Secrets yourself and set `secretName` and `cnpg.bootstrap.existingSecret` (or use an external database).

## Demo Fixtures

Set `demo.enabled=true` to add an init container to the backend that runs `/app/fixtures/generate_entities.py`.

- The init container uses the same database configuration as the InfraKitchen pods.
- This is intended for demo environments.
- The fixtures create PostgreSQL state backend integrations whose databases (`ik_tf_states_<env>`) are created on demand,
  so the chart-managed CNPG cluster grants `CREATEDB` to `database.user`. This only applies when the cluster is created;
  for an existing cluster run `ALTER ROLE <database.user> CREATEDB` as the `postgres` superuser.
