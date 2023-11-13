# Crossplane Cluster Import

This repository defines how clusters from the major cloud providers are
bootstrapped as workload clusters inside Giantswarm management clusters.

By using [Crossplane] as an intermediary, the compositions under
[crossplane/composition] discover resources related to the cluster and map these
to resources required by [Cluster Api].

In order for existing clusters to be imported into [Cluster Api] (CAPI) this set
of Composite resources exists to facilitate the creation of CAPI resources
inside the Kubernetes management cluster.

This works in three parts. Crossplane Observation, resource creation, CAPI
Observation.

> **Note**
>
> If you're new to crossplane and wish to get an understanding of how the
> components work together, please see the [composition breakdown]
> document.

At present the following providers are supported, or plan to be supported by the
compositions supplied here.

- [AWS](#aws) _Development complete_
- [Azure](#azure) _Planned, in progress_
- [GCP](#google-cloud) _Planned, in progress_

All compositions sit behind the same simplified definition and require at the
very least just the cluster name and the region / location that the cluster is
located in.

Azure users must supply one other piece of information which is the resource
group name.

For example, to make a claim against the AWS provider, at the bare minimum your
claim should look like:

```yaml
---
apiVersion: crossplane.giantswarm.io/v1alpha1
kind: ImportClaim
metadata:
  name: CLAIM_NAME
  namespace: CLAIM_NAMESPACE
spec:
  clusterName: CLUSTER_NAME
  regionOrLocation: REGION
  cloudProviderConfigRef: aws-provider
  clusterProviderConfigRef: kubernetes-provider

  compositionUpdatePolicy: Automatic # alternative "Manual"
  compositionSelector:
    matchLabels:
      provider: aws
      component: aws-eks-import
```

Additionally the following properties may also be set:

- `kubernetesAdditionalLabels` A set of labels to apply to all resources created
  by the `crossplane-contrib/provider-kubernetes` provider
- `deletionPolicy` The general deletion policy to apply to all resources.
  Default: `Delete`
- `objectDeletionPolicy` The policy to apply to
  `crossplane-contrib/provider-kubernetes` objects. Default: `Delete`
- `resourceGroupName` **Required if provider is Azure** ignored for all other
  providers

## AWS

## Requirements

In order to function corrrectly, the following crossplane components must be
installed.

- crossplane - Minimum version `v1.14.0`
- upbound/provider-family-aws - Minimum version `v0.43.0`
- upbound/provider-aws-ec2 - Minimum version `v0.43.0`
- upbound/provider-aws-eks - Minimum version `v0.43.0`
- crossplane-contrib/provider-kubernetes  - Minimum version `v0.9.0`

Additionally, the following composition functions must be installed.

- crossplane-contrib/function-patch-and-transform
- giantswarm/crossplane-fn-generate-subnets
- giantswarm/crossplane-fn-describe-nodegroups

![Crossplane to ClusterAPI relationships]

## Prerequisites

Before clusters can be imported into the CAPI provider for AWS (CAPA), resources
in the cloud account must first be tagged for discovery.

This is achieved by adding the following:

- `cluster` must have the tag `kubernetes.io/cluster/CLUSTER_NAME: owned`
- `nodegroup` must have the tag `kubernetes.io/cluster/CLUSTER_NAME: owned`
- `autoscaling group` must have the tag `kubernetes.io/cluster/CLUSTER_NAME: owned`
- `subnets` must have the tag `kubernetes.io/cluster/CLUSTER_NAME: shared`
- Cluster `securitygroup` must have the tag `kubernetes.io/cluster/CLUSTER_NAME: owned`

If these tags do not exist, they will be reported by the CAPA controller against
the `AWSManagedControlPlane` object at point of import.

## Crossplane Observation

In order to import EKS clusters, crossplane needs the following pieces of
information:

- The cluster name
- The region the cluster is built in

The composition then creates `ObserveOnly` resources for the required Cluster
and any required supporting infrastructure for that provider.

> In this instance, `ObserveOnly` is a shorthand description for resources
> created with the following properties:
>
> ```yaml
> spec:
>   managementPolicies:
>   - Observe
> ```
>
> When created in this manner, crossplane cannot alter or modify the resource
> in any fashion.
>
> For more information, see the documentation on [Management policies]

Once observe resources have reconciled, crossplane then uses this information
to create relevant resources in ClusterAPI.

## Installation

Once crossplane has been configured correctly and all providers installed, the
next step is to  install the composite resource definition and composition.

**Note** The instructions given here will be manual but these may be done with
fluxcd in a real installation scenario. See [installing with fluxcd] for
instructions on how to achieve this.

```bash
k apply -f crossplane/composition/definition.yaml
k apply -f crossplane/composition/composition-aws.yaml
```

Next, we need to apply the provider config.

Edit the [`aws providerconfig`] file and set the account id to that of the
account you are installing this in. Then apply the file

```bash
k apply -f providerconfig.yaml
```

Finally edit the claim and apply this.

```bash
k apply -f aws-claim.yaml
```

### Cluster Deletion

When deleting a cluster that is managed by external resources, this may get
stuck actually trying to delete the cluster. This is a by-product of an issue in
Cluster Api for AWS which is pending release.

As Cluster Api is blocked via IAM policy then it is considered safe to remove
the finalisers from all stuck objects.

- AWSManagedMachinePool
- AWSManagedControlPlane

## Azure

> TBD

The composition for Azure have not yet been completed.

## Google Cloud

> TBD

The composition for Google cloud has not yet been completed

## Troubleshooting

With crossplane managed resources it's often hard to understand exactly where
to start when troubleshooting errors.

The easiest way to understand this is to follow the chain down from the
`Composition`.

Start by describing the composition kind and looking for errors on the status.

For example, as part of this repository, the composition kind is
`CompositeImport` and has the name composed of the elements
`${clusterName}-XXXXX` where XXXXX is a unique 5 character identifier.

Errors on the composition kind commonly occur when expected resources are not
created and are often the result of patching failures to/from unexpected or
non-existant fields.

A successfully applied composition kind should have events similar to the
following:

```nohighlight
Type    Reason             Age                    From                                                             Message
----    ------             ----                   ----                                                             -------
Normal  ComposeResources   38m (x737 over 12h)    defined/compositeresourcedefinition.apiextensions.crossplane.io  Successfully composed resources
Normal  SelectComposition  3m33s (x772 over 12h)  defined/compositeresourcedefinition.apiextensions.crossplane.io  Successfully selected composition
```

If the composition fails to yield any errors then the next place to look is at
the claim type which in this instance would be `ImportClaim ${clusterName}`

Both the claim type and the composition kind should have an identical reflection
of any patched fields using the type `ToCompositeFieldPath`. This means that
either can be used to validate the information you're patching between resources
may be used to validate the information is correct.

The claim may not show any events as these are normally trapped by the
composition kind.

If neither of these two locations reveals any issues, then you need to start
following the resources created by the claim.

For kubernetes resources there are two types created, first the `Object` type,
then the type the `Object` implements.

If the object implementation has been created, check it for errors. If it has not
then the object may offer details on why it's not building the resource.

For non-kubernetes objects (e.g. those generated by the AWS family providers),
then any errors should show up in the status of those resources.

When all else fails, check the logs for the related components, for example
logs for Nodegroup objects will show up in the logs for
`crossplane:provider-aws-eks`.

[Crossplane]: https://docs.crossplane.io/
[crossplane/composition]: ./crossplane/composition
[Cluster Api]: https://cluster-api.sigs.k8s.io/
[composition breakdown]: ./docs/composition-breakdown.md
[installing with fluxcd]: ./docs/installing-with-fluxcd.md
[`aws providerconfig`]: ./crossplane/config/providerconfig.yaml
[Management policies]: https://docs.crossplane.io/v1.13/concepts/managed-resources/#managementpolicies
[Crossplane to ClusterAPI relationships]: ./docs/images/crossplane-capi-relationships.drawio.png