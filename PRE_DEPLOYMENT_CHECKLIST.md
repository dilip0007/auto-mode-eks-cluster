# 📋 PRE-DEPLOYMENT CHECKLIST

Use this checklist before deploying to ensure everything is configured correctly.

## ✅ AWS Account Preparation

- [ ] AWS Account is active and accessible
- [ ] AWS CLI is installed: `aws --version`
- [ ] AWS credentials configured: `aws sts get-caller-identity`
- [ ] IAM user/role has sufficient permissions (Admin or EKS-specific)
- [ ] AWS region decided and noted: _______________
- [ ] Account limits checked (service quotas)

## ✅ Local Environment Setup

- [ ] Terraform installed: `terraform --version` (>= 1.0)
- [ ] kubectl installed: `kubectl version --client`
- [ ] Git installed (optional but recommended)
- [ ] Code editor installed (VSCode, vim, nano, etc.)
- [ ] Terminal/command line access

## ✅ Configuration Review

### terraform.tfvars Customization

- [ ] `aws_region` set to your preferred region
- [ ] `cluster_name` is unique and descriptive
- [ ] `availability_zones` match your region
- [ ] **CRITICAL**: `cluster_endpoint_public_access_cidrs` restricted to your IP
  - Current value: _______________
  - Your IP address: _______________
  - [ ] Confirmed restricted (not 0.0.0.0/0 in production)

### Network Configuration

- [ ] `vpc_cidr` doesn't conflict with existing networks
- [ ] `private_subnet_cidrs` are within VPC CIDR
- [ ] `public_subnet_cidrs` are within VPC CIDR
- [ ] NAT Gateway strategy decided:
  - [ ] High Availability (multi-NAT, $96/month)
  - [ ] Cost Optimized (single-NAT, $32/month)

### Security Settings

- [ ] `enable_cluster_encryption` = true (recommended)
- [ ] `enable_irsa` = true (recommended)
- [ ] Reviewed IAM permissions in iam.tf
- [ ] Understand security group rules in security-groups.tf

### Cost Considerations

- [ ] Monthly budget calculated (see README.md)
- [ ] AWS Budgets configured or planned
- [ ] Cost alerts email set up
- [ ] Team aware of ongoing costs

## ✅ Pre-Deployment Validation

### Code Validation

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Check for syntax errors
```

- [ ] All files formatted
- [ ] Configuration valid
- [ ] No syntax errors

### Dry Run

```bash
# Initialize Terraform
terraform init

# Generate plan
terraform plan -out=tfplan

# Review plan output
```

- [ ] Terraform initialized successfully
- [ ] Plan generated without errors
- [ ] Reviewed resources to be created (~60 resources)
- [ ] No unexpected changes or deletions

### Expected Resources Count

Verify plan shows approximately:
- [ ] 1 VPC
- [ ] 6 Subnets
- [ ] 1-3 NAT Gateways
- [ ] 1 Internet Gateway
- [ ] ~6 Route tables and associations
- [ ] 1 EKS Cluster
- [ ] 4 EKS Addons
- [ ] ~10 IAM Roles and Policies
- [ ] 3-4 Security Groups
- [ ] 2 CloudWatch Log Groups
- [ ] 1 KMS Key

## ✅ Business/Team Readiness

- [ ] Stakeholders informed about deployment
- [ ] Deployment time window scheduled
- [ ] Team members have necessary access
- [ ] Documentation reviewed by team
- [ ] Rollback plan understood
- [ ] Incident response plan in place

## ✅ Post-Deployment Preparation

- [ ] kubectl configuration command ready
- [ ] Sample application deployment planned
- [ ] Monitoring setup planned
- [ ] Backup strategy defined
- [ ] Update schedule planned

## ✅ Documentation

- [ ] README.md reviewed
- [ ] CODE_EXPLANATION.md reviewed (optional but helpful)
- [ ] QUICK_START.md reviewed
- [ ] Team access to documentation

## ✅ Final Checks Before `terraform apply`

- [ ] All above checkboxes completed
- [ ] Sitting at computer (deploy takes ~20 minutes)
- [ ] Network connection stable
- [ ] Not deploying on Friday evening 😄
- [ ] Coffee/tea ready ☕

## 🚦 Deployment Decision

### If ALL checks passed:

```bash
# Execute deployment
terraform apply tfplan

# Type 'yes' when prompted
```

### If ANY checks failed:

**STOP** - Do not proceed with deployment
1. Review failed items
2. Fix configuration
3. Re-run validation
4. Return to this checklist

## 📝 Deployment Notes

Record important information during deployment:

**Deployment Start Time**: _______________

**Deployment End Time**: _______________

**Cluster Name**: _______________

**Cluster Endpoint**: _______________

**OIDC Provider**: _______________

**Any Issues Encountered**:
_____________________________________________
_____________________________________________
_____________________________________________

## ✅ Post-Deployment Verification

After `terraform apply` completes:

- [ ] No errors in Terraform output
- [ ] All resources created successfully
- [ ] Outputs displayed correctly
- [ ] kubectl configuration command executed
- [ ] `kubectl get nodes` works
- [ ] `kubectl get pods -A` shows system pods
- [ ] Sample application deployed successfully
- [ ] LoadBalancer accessible (if deployed)
- [ ] CloudWatch logs visible
- [ ] Costs appearing in AWS Cost Explorer

## 🎉 Deployment Complete!

**Status**: [ ] Success [ ] Failed [ ] Partial

**Next Steps**:
1. [ ] Configure monitoring
2. [ ] Set up CI/CD
3. [ ] Deploy production applications
4. [ ] Schedule review meeting

---

**Checklist completed by**: _______________

**Date**: _______________

**Signature**: _______________

---

## 🆘 Troubleshooting Common Issues

### Issue: Terraform init fails

**Solution**:
```bash
# Clear cache
rm -rf .terraform
rm .terraform.lock.hcl

# Re-initialize
terraform init
```

### Issue: Insufficient permissions

**Solution**:
```bash
# Check current user
aws sts get-caller-identity

# Verify permissions with your AWS admin
```

### Issue: Resource limit exceeded

**Solution**:
```bash
# Check service quotas
aws service-quotas list-service-quotas --service-code eks

# Request increase through AWS Console
```

### Issue: VPC CIDR conflict

**Solution**:
```bash
# Check existing VPCs
aws ec2 describe-vpcs

# Choose non-conflicting CIDR in terraform.tfvars
```

---

**Keep this checklist for your records and future deployments!**
