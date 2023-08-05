# IAM Permissions for importing EKS clusters

The following permission sets are required for reading cluster resources and
setting required information.

Overall this is largely a read only policy document with some additional write
capabilities.

> **Note** This document may still be incomplete. Not all resources have moved
> through to completion and other permissions may be required for all required
> components to be managed fully by CAPI.

## Autoscaling

- `autoscaling:DescribeAutoScalingGroups`

### Autoscaling Tagging

- `autoscaling:DeleteTags`
- `autoscaling:DescribeTags`
- `autoscaling:CreateOrUpdateTags`

## EC2

### Instances

- `ec2:DescribeInstances`
- `ec2:DescribeReservedInstances`
- `ec2:DescribeFleetInstances`
- `ec2:DescribeScheduledInstances`
- `ec2:DescribeSpotFleetInstances`
- `ec2:DescribeInstanceTypes`
- `ec2:DescribeInstanceAttribute`
- `ec2:DescribeInstanceStatus`

### Security groups

For CAPI to be able to create security groups for the loadbalancer, this
requires a full set of permissions.

- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress`
- `ec2:UpdateSecurityGroupRuleDescriptionsIngress`
- `ec2:UpdateSecurityGroupRuleDescriptionsEgress`
- `ec2:ModifySecurityGroupRules`
- `ec2:RevokeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupEgress`
- `ec2:CreateSecurityGroup`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeSecurityGroupReferences`
- `ec2:DeleteSecurityGroup`
- `ec2:DescribeStaleSecurityGroups`
- `ec2:DescribeSecurityGroupRules`

### Subnets

- `ec2:DescribeSubnets`

### EC2 Tagging

- `ec2:CreateTags`
- `ec2:DeleteTags`
- `ec2:DescribeTags`

### VPC

- `ec2:DescribeVpcAttribute`
- `ec2:DescribeVpcs`

## EKS

### Fargate

- `eks:ListFargateProfiles`
- `eks:DescribeFargateProfile`

### Addons

- `eks:ListAddons`
- `eks:DescribeAddon`
- `eks:DescribeAddonConfiguration`
- `eks:DescribeAddonVersions`

### NodeGroups

- `eks:ListNodegroups`
- `eks:DescribeNodegroup`
- `eks:UpdateNodegroupConfig`

### Clusters

- `eks:ListClusters`
- `eks:DescribeCluster`

### Updates

- `eks:ListUpdates`
- `eks:DescribeUpdate`

### Kubernetes API

- `eks:AccessKubernetesApi`

### Tagging EKS resources

- `eks:TagResource`
- `eks:UntagResource`
- `eks:ListTagsForResource`

### IdentityProviders

- `eks:AssociateIdentityProviderConfig`
- `eks:DisassociateIdentityProviderConfig`
- `eks:DescribeIdentityProviderConfig`
- `eks:ListIdentityProviderConfigs`

## IAM

- `iam:GetRole`

## STS

- `sts:AssumeRole`

To prevent AssumeRole being too open, it should have the following condition
placed on it.

```json
"Condition": {
    "ForAnyValue:StringLike": {
        "aws:PrincipalArn": [
            "arn:aws:sts::${AWS_ACCOUNT_ID}:role/crossplane-assume-role",
            "arn:aws:sts::${AWS_ACCOUNT_ID}:assumed-role/eks-import-crossplane-role*"
        ]
    }
}
```
