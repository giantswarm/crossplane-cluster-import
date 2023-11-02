# AWS (EKS) Clusters

## IAM Permissions

In order to collect information from AWS, crossplane requires read only
permissions for EKS and some EC2 resources.

CAPI requires an enhanced permission set that includes some write actions for
tagging and security group creation.

For a breakdown of the permissions used by this composition, please see the
document [iam-permissions](./iam-permissions.md).

## Providers

For crossplane to be able to read from AWS and create Kubernetes objects, the
following providers must be installed.

- `upbound/provider-aws-ec2`
- `upbound/provider-aws-eks`
- `crossplane-contrib/provider-kubernetes`

To install and configure the cloud providers, please see the documentation in
[`management-cluster-bases`](https://github.com/giantswarm/management-cluster-bases/tree/main/extras/crossplane)

To install and configure the `kubernetes provider, please see the documentation
on [setting up provider-kubernetes](./install-kubernetes-provider.md)

### IRSA configuration for AWS crossplane providers

IRSA must be configured on the service account linked to each of the pods in the
`provider-aws` family. For instructions on how to set this up, please see the
documentation [Using `crossplane` with IAM Roles for Service Accounts](https://github.com/giantswarm/management-cluster-bases/tree/main/extras/crossplane/providers/upbound/aws#using-crossplane-with-iam-roles-for-service-accounts).

Once the provider pods have been installed, a secondary role needs to be created
for both crossplane and CAPI to bind on to. For documentation on setting up that
role, please see the [Secondary role instructions](./docs/secondary-role-instructions.md)