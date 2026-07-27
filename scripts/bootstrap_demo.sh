#!/bin/sh

echo "Install RabbitMQ and PostgreSQL operators and CRDs before installing this chart."
echo "Install cert-manager for certificate management (required for RabbitMQ operator):"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo "Wait for cert-manager rollout:"
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s

echo "Install RabbitMQ operator:"
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

echo "Wait for RabbitMQ operator rollout:"
kubectl rollout status deployment/rabbitmq-cluster-operator -n rabbitmq-system --timeout=300s

echo "Install CNPG operator for PostgreSQL:"
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-1.30.0.yaml

echo "Wait for CNPG operator rollout:"
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system --timeout=300s

echo "Install InfraKitchen chart:"
helm upgrade --install test charts/infrakitchen --set "cnpg.bootstrap.password=test" --set "global.imageTag=0.4.0-20260728121251" --set "demo.enabled=true" \
  --set "secrets.encSecret=MWhVVmYtQ3dFNDc3ODdrTEJ1TUx4cUpLcm1ZTFQ4TlRsZlY0RnpMV0owVT0=" -n ik --create-namespace
