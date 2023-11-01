#!/bin/bash
#go generate ./...
#docker build . -t docker.io/choclab/function-generate-subnets:v0.0.1
#docker push choclab/function-generate-subnets:v0.0.1
readonly mc=snail

kind delete cluster -n xfn
kind create cluster -n xfn
kubectl config use-context kind-xfn

helm repo add crossplane https://charts.crossplane.io/master/
helm repo update

# Requires AWS credentials to be set up with profile [snail]
eval $(awk -v mc=$mc '$0 ~ mc {x=NR+2; next; }(NR<=x){print "export "toupper($1)"="$3;}' ~/.aws/credentials)

# Requires aws config to be set up for profile [snail] IN ORDER
# ```
# [snail]
# region=<region>
# ```
eval $(awk -v mc=$mc '$0 ~ mc{x=NR+1; next; }(NR<=x){print "export AWS_"toupper($1)"="$3;}' ~/.aws/config)

export GOPROXY=off
# Install CAPI/CAPA - does not require stack initialisation
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

# export EXP_CLUSTER_RESOURCE_SET=true
export EXP_MACHINE_POOL=true
clusterctl init --infrastructure=aws:v2.2.2

# Install crossplane
helm install crossplane --namespace crossplane --create-namespace crossplane-master/crossplane --devel
echo "Waiting for crossplane CRDs"
until grep -q functions <<<$(kubectl get crds 2>/dev/null); do
    echo -n .
    sleep 1
done
echo

# TODO: Ammend this to point at the secret containing your credentials
kubectl create secret generic aws-credentials -n crossplane --from-literal=creds="$(
  base64 -d <<< ${AWS_B64ENCODED_CREDENTIALS}
)"

kubectl apply -f examples/controllers.yaml
echo "Waiting for provider CRDs"
until grep -q 'providerconfigs.aws.upbound.io' <<<$(kubectl get crds 2>/dev/null) && grep -q 'providerconfigs.kubernetes.crossplane.io' <<<$(kubectl get crds 2>/dev/null); do
    echo -n .
    sleep 1
done
echo
exit
cat <<EOF | kubectl apply -f -
---
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: snail
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane
      name: aws-credentials
      key: creds
---
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
EOF

kubectl apply -f examples/xrender/functions.yaml

# Wait for functions to become ready
until
    kubectl get functions function-generate-subnets -o yaml | yq '.status.conditions[] | select(.type == "Healthy" and .status == "True")' | grep -q "True" &&
        kubectl get functions function-generate-subnets -o yaml | yq '.status.conditions[] | select(.type == "Healthy" and .status == "True")' | grep -q "True" ;
do
    echo -n .
    sleep 1
done
echo

kubectl create namespace org-sample

#kubectl apply -f examples/xrender/definition.yaml
#kubectl apply -f examples/xrender/composition.yaml
#sleep 10
#kubectl apply -f examples/xrender/claim.yaml
