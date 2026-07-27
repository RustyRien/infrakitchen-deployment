# infrakitchen-deployment

A centralized repository for packaging, containerizing, and deploying the InfraKitchen ecosystem. It automates **Docker image builds** and manages **Kubernetes (K8s) manifests** for reliable multi-environment GitOps deployment.

## Getting Started

For testing purposes [Minikube](https://minikube.sigs.k8s.io/docs/start/) can be used.
kubectl and helm must be installed on your local machine.

You can do bootstrap a local cluster with the following command:

```bash
minikube start --cpus=6 --memory=10192
sh scripts/bootstrap_demo.sh
```

When the cluster is ready, you can port-forward the service to your local machine:

```bash
kubectl port-forward svc/test-infrakitchen 8080 -n ik
```

Open your browser and navigate to [http://localhost:8080](http://localhost:8080) to access the InfraKitchen UI.
Login with Guest Super user to get full access to the demo.

## Clean Up

To clean up the local setup when you are done, stop the port-forward process, delete the demo resources if they are still present with `kubectl delete namespace ik`, delete Persistent Volumes, and remove the local Minikube cluster with `minikube delete`. This returns your machine to a clean state and removes the Kubernetes workloads, services, and cluster created for the demo.
