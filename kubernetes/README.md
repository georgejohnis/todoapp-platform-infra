# Platform Kubernetes Resources

This directory contains Kubernetes manifests managed by the platform team through GitOps practices using ArgoCD.

## Directory Structure

- `argocd/`: ArgoCD-related configurations
  - `applications/`: ArgoCD Application CRDs
  - `config/`: ArgoCD installation and configuration

- `namespaces/`: Namespace definitions for applications
  - `todo-app.yaml`: Todo application namespace

- `platform/`: Other platform-level resources

## GitOps Workflow

1. Changes to these manifests should be made through pull requests
2. ArgoCD automatically syncs changes once merged to main
3. Each subdirectory is managed by its own ArgoCD Application
4. Namespace creation/management is automated through the platform-namespaces Application

## Prerequisites

- EKS cluster must be running (managed by Terraform)
- ArgoCD must be installed in the cluster
- Proper RBAC and access controls must be in place 