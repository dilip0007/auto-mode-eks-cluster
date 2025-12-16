# Makefile for EKS Auto Mode Terraform Operations
# This file provides convenient commands for managing your infrastructure

.PHONY: help init plan apply destroy validate fmt clean kubectl-config

# Default target - show help
help:
	@echo "════════════════════════════════════════════════════════════════"
	@echo "  EKS Auto Mode Terraform Operations"
	@echo "════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make init          - Initialize Terraform"
	@echo "  make validate      - Validate Terraform configuration"
	@echo "  make fmt           - Format Terraform files"
	@echo "  make plan          - Show execution plan"
	@echo "  make apply         - Apply changes"
	@echo "  make destroy       - Destroy all resources"
	@echo "  make kubectl-config - Configure kubectl"
	@echo "  make outputs       - Show outputs"
	@echo "  make clean         - Clean Terraform files"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════"

# Initialize Terraform
init:
	@echo "🔧 Initializing Terraform..."
	terraform init

# Validate configuration
validate:
	@echo "✅ Validating Terraform configuration..."
	terraform validate

# Format Terraform files
fmt:
	@echo "📝 Formatting Terraform files..."
	terraform fmt -recursive

# Create execution plan
plan:
	@echo "📋 Creating execution plan..."
	terraform plan -out=tfplan

# Apply changes
apply:
	@echo "🚀 Applying Terraform changes..."
	@echo "⚠️  This will create real resources and incur costs!"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform apply tfplan; \
		rm -f tfplan; \
		echo "✅ Deployment complete!"; \
		echo ""; \
		echo "Run 'make kubectl-config' to configure kubectl"; \
	else \
		echo "❌ Deployment cancelled"; \
	fi

# Destroy all resources
destroy:
	@echo "⚠️  WARNING: This will destroy ALL resources!"
	@echo "⚠️  This action cannot be undone!"
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" = "destroy" ]; then \
		terraform destroy; \
		echo "✅ Resources destroyed"; \
	else \
		echo "❌ Destroy cancelled"; \
	fi

# Configure kubectl
kubectl-config:
	@echo "🔧 Configuring kubectl..."
	@CLUSTER_NAME=$$(terraform output -raw cluster_name 2>/dev/null); \
	AWS_REGION=$$(terraform output -raw aws_region 2>/dev/null); \
	if [ -z "$$CLUSTER_NAME" ] || [ -z "$$AWS_REGION" ]; then \
		echo "❌ Cluster not found. Run 'make apply' first."; \
		exit 1; \
	fi; \
	aws eks update-kubeconfig --region $$AWS_REGION --name $$CLUSTER_NAME; \
	echo "✅ kubectl configured successfully"; \
	echo ""; \
	echo "Test with: kubectl get nodes"

# Show outputs
outputs:
	@echo "📊 Terraform Outputs:"
	@echo ""
	@terraform output

# Clean Terraform files
clean:
	@echo "🧹 Cleaning Terraform files..."
	rm -f tfplan
	rm -f terraform.tfstate.backup
	@echo "✅ Cleanup complete"

# Full deployment workflow
deploy: init validate fmt plan apply kubectl-config
	@echo "✅ Full deployment complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  kubectl get nodes"
	@echo "  kubectl get pods -A"
