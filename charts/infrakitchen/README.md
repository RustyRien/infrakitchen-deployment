# InfraKitchen Helm Chart

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

## RabbitMQ

This chart manages a RabbitMQ `RabbitmqCluster` by default.

- Install the RabbitMQ Cluster Operator and CRDs before installing this chart.
- Follow the official operator install docs: <https://www.rabbitmq.com/kubernetes/operator/install-operator>
- If `rabbitmq.auth.existingSecret` is not set, this chart uses the RabbitMQ operator-generated `<cluster-name>-default-user` Secret.
- In managed mode, InfraKitchen reads `username` and `password` from that Secret and builds `BROKER_URL` against the managed RabbitMQ service.

### Managed RabbitMQ

Install the chart after the RabbitMQ Cluster Operator is available.
If you want to override the operator-generated secret, set `rabbitmq.auth.existingSecret` to a Secret that provides `username` and `password`.

### External RabbitMQ

Set:

- `rabbitmq.external.enabled=true`
- either `rabbitmq.external.uri`
- or `rabbitmq.external.host` and `rabbitmq.external.existingSecret`

In external mode, this chart does not render RabbitMQ operator resources.

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

## Demo Fixtures

Set `demo.enabled=true` to create a Init container that runs `/app/fixtures/generate_entities.py`.

- The Job uses the same database configuration as the InfraKitchen pods.
- This is intended for demo environments.
