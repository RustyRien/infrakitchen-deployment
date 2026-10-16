# InfraKitchen Helm Chart

Deploys the InfraKitchen backend, worker and scheduler, backed by PostgreSQL.
Requires Kubernetes 1.30+.

## Workloads

The chart renders three Deployments from the same image: `backend` (API, UI and migrations), `worker` and `scheduler`.
Each one has its own block in `values.yaml` with the same set of options (image, resources, probes, security contexts, scheduling, extra env/volumes/containers).

- The image tag defaults to the chart `appVersion`. Override it for all workloads with `global.imageTag`, or per workload with `<workload>.image.tag`.
- The scheduler uses the `Recreate` strategy so two schedulers never run at the same time during a rollout.
- `backend.pdb.enabled=true` adds a PodDisruptionBudget for the backend.

## Security defaults

Pods run as the image's non-root `infrakitchen` user (UID/GID 1000) with the `RuntimeDefault` seccomp profile.
Containers drop all capabilities and disallow privilege escalation, and the ServiceAccount token is not mounted.
`readOnlyRootFilesystem` is not enabled because nginx, OpenTofu and git write to the image filesystem.
Override `<workload>.podSecurityContext` and `<workload>.containerSecurityContext` if your platform needs different settings.

## Values validation

`values.schema.json` rejects unknown keys and wrong types, so typos and settings removed in newer chart versions fail at install time instead of being silently ignored.

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
