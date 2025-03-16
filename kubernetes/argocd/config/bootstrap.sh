#!/bin/bash

# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD CRDs and controller
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.1/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply our ArgoCD Application that will manage ArgoCD itself
kubectl apply -f install.yaml

# Get the initial admin password
echo "ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo "\n"

# Print the ArgoCD URL
echo "ArgoCD URL:"
kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 