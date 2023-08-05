# Installing with fluxcd

Inside your `CUSTOMER_NAME-management-clusters` repository, create a new
folder `management-clusters/MC_NAME/eks-clusters/EKS_CLUSTER_NAME` and then
create a `kustomization.yaml` at this location.

The contents of this kustomization are:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://github.com/giantswarm/crossplane-eks-capi-import/?ref=main
patches:
  - patch: |
      - op: replace
        path: /metadata/name
        value: EKS_CLUSTER_NAME # <- Set this to the name of your EKS cluster
      - op: replace
        path: /metadata/namespace
        value: CLAIM_NAMESPACE  # <- Set this to the namespace you want to create the claim in
      - op: replace
        path: /metadata/labels/owner
        value: OWNER_NAME       # <- Set this to the team name that owns the cluster

      - op: replace
        path: /spec/namespace
        value: ORG_NAMESPACE    #  <- Set this to the organization namespace for your EKS cluster
      - op: replace
        path: /spec/parameters/clusterName
        value: EKS_CLUSTER_NAME # <- Set this to the name of your EKS cluster
      - op: replace
        path: /spec/parameters/nodeGroupName
        value: NODE_GROUP_NAME  # <- Set this to the name of the cluster nodegroup
      - op: replace
        path: /spec/parameters/region
        value: AWS_REGION      # <- Set this to the region your cluster is located in
    target:
      kind: EksImportClaim
```

## Flux binding

The file `providerconfig` contains account variables that need to be replaced.

As the import resources cannot be created until crossplane is deployed, we use
the `postBuild` variables to feed this information.

Create a new file `crossplane-eks.yaml` in `management-clusters/MC_NAME` with the
following contents, setting the variable `AWS_ACCOUNT_ID` to the account the
management cluster is located in.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: crossplane-resources
  namespace: default
spec:
  interval: 1m
  path: "./management-clusters/MC_NAME/eks-clusters/"
  postBuild:
    substitute:
      AWS_ACCOUNT_ID: "1234567890"
  prune: false
  serviceAccountName: automation
  sourceRef:
    kind: GitRepository
    name: management-clusters-fleet
  timeout: 2m
```

Finally, add this as a resource in `management-clusters/MC_NAME/kustomization.yaml`
