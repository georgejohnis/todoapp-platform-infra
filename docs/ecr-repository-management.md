# ECR Repository Management Guide

## Overview
This document provides guidelines for creating, using, and managing Elastic Container Registry (ECR) repositories in our Kubernetes platform.

## Repository Creation Process

### Naming Conventions
- Repository names should follow the format: `<app-name>-repo`
- Use lowercase letters and hyphens
- Prefix with the application or service name
- Example: `todo-app-repo`, `user-service-repo`

### Lifecycle Management
- Repositories are managed using AWS Controllers for Kubernetes (ACK)
- Stored in the `kube-system` namespace for cluster-wide accessibility
- Default lifecycle policy:
  - Tagged images are kept for 30 days
  - Untagged images are automatically pruned

## Request a New Repository

### Prerequisites
- Approved project in the platform
- Defined application namespace
- Completed security review

### Submission Process
1. Create a pull request to `todoapp-platform-infra` repository
2. Add a new repository definition in `kubernetes/infrastructure/ecr/`
3. Follow the template below:

```yaml
apiVersion: ecr.services.k8s.aws/v1
kind: Repository
metadata:
  name: <app-name>-repo
  namespace: kube-system
  labels:
    app: <app-name>
    managed-by: platform-team
spec:
  repositoryName: <app-name>
  imageTagMutability: MUTABLE  # or IMMUTABLE based on requirements
  lifecyclePolicy:
    rules:
      - rulePriority: 1
        selection:
          tagStatus: TAGGED
        action:
          type: EXPIRY
          expiry: 30  # Days to retain images
```

## Best Practices

### Image Tagging
- Use semantic versioning: `v1.2.3`
- Include environment tags: `dev`, `staging`, `prod`
- Use commit hash for traceability
- Example tags:
  - `v1.2.3-dev`
  - `main-abc1234`
  - `prod-release`

### Security
- Enable image scanning
- Use least-privilege IAM roles
- Rotate credentials regularly
- Implement image signing (optional)

## Troubleshooting

### Common Issues
- **Permission Denied**: Ensure correct IAM roles are assigned
- **Image Not Found**: Verify repository name and tags
- **Lifecycle Policy Conflicts**: Review expiration rules

## Contact
- Platform Team: platform-engineering@company.com
- Slack Channel: #platform-infrastructure

## Changelog
- 2024-03-16: Initial documentation
- Maintained by Platform Engineering Team 