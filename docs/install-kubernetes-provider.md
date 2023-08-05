# Install the kubernetes provider

> **Note** Move this to management-cluster-bases

Inside your `CUSTOMER_NAME-management-clusters` repository, change to the
directory `management-clusters/MC_NAME/crossplane-providers` folder and create
a new folder at this location called `kubernetes`.

At this location, create the following files:

## Provider

```yaml
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: crossplane-contrib-provider-kubernetes
  namespace: crossplane
spec:
  controllerConfigRef:
    name: crossplane-contrib-provider-kubernetes
  ignoreCrossplaneConstraints: false
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:${VERSION}
  packagePullPolicy: IfNotPresent
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 0
  skipDependencyResolution: false
```

Set `VERSION` to the latest version available from
[provider-kubernetes](https://doc.crds.dev/github.com/crossplane-contrib/provider-kubernetes)

## ControllerConfig

```yaml
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: crossplane-contrib-provider-kubernetes
  namespace: crossplane
spec:
  args:
    - --debug
  serviceAccountName: "crossplane-provider-kubernetes"
```

## Service Account

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: crossplane-provider-kubernetes
  namespace: crossplane
  annotations: {}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: crossplane-use-psp-upbound-provider
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: crossplane-use-psp
subjects:
- kind: ServiceAccount
  name: crossplane-provider-kubernetes
  namespace: crossplane
```

## Bind Service account

The service account created as part of this setup needs an additional binding
to a `ClusterRole` that has permissions to operate on the cluster. In this
instance, we're using `cluster-admin` but in a real world scenario, this would
be a far more restricted role.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: crossplane-use-psp-upbound-provider
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: crossplane-provider-kubernetes
  namespace: crossplane
```
