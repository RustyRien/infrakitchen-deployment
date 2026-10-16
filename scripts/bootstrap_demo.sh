#!/bin/sh

echo "Install PostgreSQL operator and CRDs before installing this chart."
echo "Install CNPG operator for PostgreSQL:"
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-1.30.0.yaml

echo "Wait for CNPG operator rollout:"
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system --timeout=300s

echo "Install InfraKitchen chart:"
helm upgrade --install test charts/infrakitchen --set "cnpg.bootstrap.password=test" --set "global.imageTag=0.4.0-20260728121251" --set "demo.enabled=true" \
  --set "secrets.encSecret=MWhVVmYtQ3dFNDc3ODdrTEJ1TUx4cUpLcm1ZTFQ4TlRsZlY0RnpMV0owVT0=" -n ik --create-namespace
