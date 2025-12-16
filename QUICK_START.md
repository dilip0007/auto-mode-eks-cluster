# 🚀 QUICK START GUIDE - EKS Auto Mode Terraform

## Prerequisites Checklist

- [ ] AWS Account (fresh/new)
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed
- [ ] Admin access or sufficient IAM permissions

## 5-Minute Deployment

### Step 1: Configure AWS Credentials

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter region: us-west-2
# Enter output format: json
```

### Step 2: Customize Configuration

Edit `terraform.tfvars`:

```bash
# ⚠️ IMPORTANT: Change these values!

# 1. Restrict API access to your IP (SECURITY CRITICAL!)
cluster_endpoint_public_access_cidrs = ["YOUR_IP_ADDRESS/32"]

# 2. Choose your region
aws_region = "us-west-2"

# 3. Name your cluster
cluster_name = "my-production-eks"

# 4. Save costs in non-production (optional)
single_nat_gateway = false  # Set to true for dev/test
```

### Step 3: Deploy

```bash
# Initialize
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~15-20 minutes)
terraform apply
```

Type `yes` when prompted.

### Step 4: Configure kubectl

```bash
# Get the command from outputs or run directly
aws eks update-kubeconfig --region us-west-2 --name production-eks-auto
```

### Step 5: Verify

```bash
# Check cluster
kubectl cluster-info

# View nodes (Auto Mode will provision as needed)
kubectl get nodes

# Check system pods
kubectl get pods -A
```

## 🎉 Success! Your EKS Cluster is Ready

### Deploy Your First App

```bash
# Create deployment
kubectl create deployment nginx --image=nginx

# Expose as LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get LoadBalancer URL (may take 2-3 minutes)
kubectl get svc nginx
```

### Access Your App

```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access your app at: http://$EXTERNAL_IP"

# Test
curl http://$EXTERNAL_IP
```

## 📊 Monitor Your Cluster

### CloudWatch Logs

```bash
# View logs in AWS Console
# Navigate to: CloudWatch > Log groups > /aws/eks/production-eks-auto/cluster
```

### Check Auto Mode

```bash
# View compute configuration
aws eks describe-cluster --name production-eks-auto \
  --query 'cluster.computeConfig' --region us-west-2

# Watch nodes being provisioned
kubectl get nodes -w
```

## 💰 Cost Monitoring

### Set Up Billing Alerts

1. Go to AWS Console > Billing > Budgets
2. Create budget: "Monthly EKS Cost"
3. Set limit: $500 (adjust as needed)
4. Add email alerts at 80%, 100%

### Estimated Monthly Costs

| Component | Cost |
|-----------|------|
| EKS Control Plane | $73 |
| NAT Gateways (3) | $96 |
| EC2 (Auto Mode) | $200-500 |
| Total | **$369-669** |

## 🔧 Common Commands

```bash
# View cluster info
kubectl cluster-info

# Get all resources
kubectl get all -A

# Describe a pod
kubectl describe pod POD_NAME

# View logs
kubectl logs POD_NAME

# Execute command in pod
kubectl exec -it POD_NAME -- bash

# Scale deployment
kubectl scale deployment nginx --replicas=3

# Delete deployment
kubectl delete deployment nginx
```

## ⚠️ Troubleshooting

### Issue: Can't connect to cluster

```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region us-west-2 --name production-eks-auto

# Verify AWS credentials
aws sts get-caller-identity
```

### Issue: No nodes appearing

```bash
# Check Auto Mode status
kubectl get pods -A

# Auto Mode provisions nodes when pods are pending
# Create a deployment to trigger node provisioning
kubectl create deployment test --image=nginx
```

### Issue: Permission denied

```bash
# Verify IAM permissions
aws iam get-user

# Check if you're the cluster creator
aws eks describe-cluster --name production-eks-auto \
  --query 'cluster.identity.oidc.issuer'
```

## 🧹 Clean Up

### Delete Everything

```bash
# Delete Kubernetes resources first
kubectl delete all --all --all-namespaces

# Wait for LoadBalancers to be deleted (check AWS Console)

# Destroy infrastructure
terraform destroy
```

Type `destroy` when prompted.

## 📚 Next Steps

1. **Security Hardening**
   - [ ] Restrict API access to specific IPs
   - [ ] Enable AWS GuardDuty
   - [ ] Implement Network Policies
   - [ ] Set up AWS Security Hub

2. **CI/CD Integration**
   - [ ] Set up GitOps with ArgoCD/Flux
   - [ ] Configure GitHub Actions/Jenkins
   - [ ] Implement automated deployments

3. **Monitoring & Logging**
   - [ ] Deploy Prometheus/Grafana
   - [ ] Set up CloudWatch Container Insights
   - [ ] Configure alerting rules

4. **Application Deployment**
   - [ ] Deploy Ingress Controller (nginx/ALB)
   - [ ] Set up cert-manager for TLS
   - [ ] Configure external-dns

## 🆘 Getting Help

- **Documentation**: See README.md and CODE_EXPLANATION.md
- **AWS Support**: If you have a support plan
- **Community**: AWS Forums, Stack Overflow
- **Issues**: GitHub Issues (if using version control)

## ✅ Checklist for Production

Before going to production, ensure:

- [ ] API access restricted to known IPs
- [ ] Backup strategy implemented
- [ ] Monitoring and alerting configured
- [ ] Network policies enabled
- [ ] Pod security policies defined
- [ ] Resource quotas set
- [ ] Cost alerts configured
- [ ] Disaster recovery plan documented
- [ ] Team trained on Kubernetes
- [ ] runbooks created

## 🎓 Learning Resources

- [EKS Workshop](https://www.eksworkshop.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/home/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**You're all set! Happy Kubernetes-ing! 🎉**
