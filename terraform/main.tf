module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # IAM roles will be created by the module
  create_iam_role = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role for Todo App
resource "aws_iam_role" "todo_app" {
  name = "todo-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Example policy for Todo App (modify based on your app's needs)
resource "aws_iam_role_policy" "todo_app" {
  name = "todo-app-policy"
  role = aws_iam_role.todo_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::todo-app-bucket",
          "arn:aws:s3:::todo-app-bucket/*"
        ]
      }
    ]
  })
}

# Enable Pod Identity feature
resource "aws_eks_pod_identity_association" "todo_app" {
  cluster_name    = module.eks.cluster_name
  namespace       = "todo-app"
  service_account = "todo-app-sa"
  role_arn       = aws_iam_role.todo_app.arn
}

# Check EKS cluster status
data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

# Install ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"  # Specify the chart version for stability

  values = [
    <<-EOT
    server:
      extraArgs:
        - --insecure # Disable TLS for demo purposes
    configs:
      cm:
        url: https://kubernetes.default.svc
        timeout.reconciliation: 180s
    EOT
  ]

  depends_on = [
    module.eks
  ]

  # Only proceed if cluster is ACTIVE
  lifecycle {
    precondition {
      condition     = data.aws_eks_cluster.main.status == "ACTIVE"
      error_message = "EKS cluster must be ACTIVE before installing ArgoCD"
    }
  }
}

# Create the ArgoCD Application for managing namespaces
resource "kubernetes_manifest" "argocd_namespaces_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform-namespaces"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "main"
        path           = "kubernetes/namespaces"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}

# Create the ArgoCD Application for managing infrastructure components
resource "kubernetes_manifest" "argocd_infrastructure_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform-infrastructure"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "main"
        path           = "kubernetes/infrastructure/ecr"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}

# Create the ArgoCD Application for managing the todo application
resource "kubernetes_manifest" "argocd_todo_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "todo-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.todo_app_repo_url  # This should be your todo-app repository URL
        targetRevision = "main"
        path           = "kubernetes/overlays/dev"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "todo-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.argocd_namespaces_app  # Ensure namespace exists first
  ]
}

# IAM Role for ACK ECR Controller
resource "aws_iam_role" "ack_ecr_controller" {
  name = "ack-ecr-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub": "system:serviceaccount:kube-system:ack-ecr-controller"
          }
        }
      }
    ]
  })
}

# IAM Policy for ECR Full Access
resource "aws_iam_role_policy_attachment" "ack_ecr_controller_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR_FullAccess"
  role       = aws_iam_role.ack_ecr_controller.name
}
