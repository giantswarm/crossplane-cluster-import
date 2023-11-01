#!/bin/bash

# This script requires an AWS profile to be set up as follows:
#
# [profilename]
# aws_access_key_id = <access-key>
# aws_secret_access_key = <secret-access-key>
# aws_account_id = <account-id>
# aws_oidc_endpoint = <oidc-endpoint>
#
# additionally, a matching profile must be configured in ~/.aws/config 
# with region on the first line below the profile name
#
# [profile profilename]
# region = <region>
# output = json
# ...

if which bwv &>/dev/null; then
  # this is custom for martin
  export GITHUB_TOKEN=$(bwv "development/github.com?field=full-access-token-never-expire" | jq -r .value);
  export AWS_PROFILE=honeybadgermc
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo GITHUB_TOKEN must be set in your environment
  exit 1
fi

[ -z "${MC_NAME}" ] && export MC_NAME=snail
[ -z "${KIND_CLUSTER_NAME}" ] && export KIND_CLUSTER_NAME=xfn

if ! grep -q "[${AWS_PROFILE}]" ~/.aws/credentials; then
  echo "AWS_PROFILE is set to ${AWS_PROFILE} but I cannot find an AWS profile with this name"
  echo "Please run 'aws configure' to set one up or export AWS_PROFILE=profilename"
  exit 1
fi

# Load AWS profile information from ~/.aws
eval $(awk -v mc=$AWS_PROFILE '$0 ~ mc {x=NR+4; next; }(NR<=x){print "export "toupper($1)"="$3;}' ~/.aws/credentials)
eval $(awk -v mc=$AWS_PROFILE '$0 ~ mc{x=NR+1; next; }(NR<=x){print "export AWS_"toupper($1)"="$3;}' ~/.aws/config)

# We need to start completely clean for this. Crossplane cam often be a pain to reconfigure once set up.
kind delete cluster -n "${KIND_CLUSTER_NAME}"

# Create a new kind cluster using the aws config
cat kindconfig/aws.yaml | envsubst > /tmp/kind-${KIND_CLUSTER_NAME}.yaml
echo "Building kind cluster with config:"
cat /tmp/kind-${KIND_CLUSTER_NAME}.yaml

kind create cluster --config /tmp/kind-${KIND_CLUSTER_NAME}.yaml -n "${KIND_CLUSTER_NAME}"
kubectl config use-context kind-"${KIND_CLUSTER_NAME}"

helm repo add crossplane https://charts.crossplane.io/master/
helm repo update

export GOPROXY=off # can't recall why this needed to be set but something broke without it in my env (martin)
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
export EXP_MACHINE_POOL=true

function wait_for_deployment() {
    namespace=$1
    deployment=$2

    echo "Waiting for $deployment deployment to become ready"
    until kubectl get deploy -n $namespace $deployment -o yaml 2>/dev/null \
        | yq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") .status' | grep -q True; 
    do
        echo -n .
        sleep 1
    done
    echo
}

function wait_for_functions() {
    functions=$@

    for function in ${functions[@]}; do
        echo "Waiting for function $function to become ready"
        until kubectl get functions $function -o yaml \
          | yq '.status.conditions[] | select(.type == "Healthy" and .status == "True")' | grep -q "True";
        do
            echo -n .
            sleep 1
        done
        echo
    done
}

function wait_for_crds() {
    crds=$@
    for crd in ${crds[@]}; do
        echo "Waiting for crossplane crd $crd"
        until grep -q $crd <<<$(kubectl get crds 2>/dev/null); do
            echo -n .
            sleep 1
        done
        echo
    done
}

# Install CAPI/CAPA - does not require stack initialisation
clusterctl init --infrastructure=aws:v2.2.2
wait_for_deployment capa-system capa-controller-manager
cat ./capa-config.yaml | envsubst | kubectl apply -f -

kubectl create namespace giantswarm
kubectl create namespace org-sample

# install IRSA operator...
echo "Installing irsa-operator"
[ -d irsa ] && rm -rf irsa
mkdir irsa && {
  cd irsa;
  git init && git remote add -f --no-tags origin git@github.com:giantswarm/irsa-operator.git &&
  git config core.sparseCheckout true && echo "helm/irsa-operator" >> .git/info/sparse-checkout &&
  git checkout master;
  cd -;
}

helm install irsa-operator --namespace giantswarm ./irsa/helm/irsa-operator \
    --set aws.accessKeyID=$AWS_ACCESS_KEY_ID,aws.secretAccessKey=$AWS_SECRET_ACCESS_KEY,region=$AWS_REGION,capa=true,legacy=false,installation.name=$MC_NAME,global.podSecurityStandards.enforced=true

wait_for_deployment giantswarm irsa-operator
rm -rf irsa

[ -d podidhook ] && rm -rf podidhook
mkdir podidhook && {
  cd podidhook
  git init && git remote add -f --no-tags origin git@github.com:aws/amazon-eks-pod-identity-webhook.git &&
  git checkout master;
  IMAGE=docker.io/amazon/amazon-eks-pod-identity-webhook make cluster-up
  cd -
} && rm -rf podidhook

# Install crossplane
helm install crossplane --namespace crossplane --create-namespace crossplane-master/crossplane --devel
echo "Waiting for crossplane CRDs"
wait_for_crds deploymentruntimeconfigs.pkg.crossplane.io providers.pkg.crossplane.io functions.pkg.crossplane.io

# TODO: Ammend this to point at the secret containing your credentials
kubectl create secret generic aws-credentials -n crossplane --from-literal=creds="$(
  base64 -d <<< ${AWS_B64ENCODED_CREDENTIALS}
)"

cat ./crossplaneconfig/aws/controllers.yaml | envsubst | kubectl apply -f -
wait_for_crds 'providerconfigs.aws.upbound.io' 'providerconfigs.kubernetes.crossplane.io'

cat ./crossplaneconfig/aws/providerconfig.yaml | envsubst | kubectl apply -f -
kubectl apply -f ./crossplaneconfig/aws/functions.yaml
wait_for_functions function-generate-subnets function-describe-nodegroups function-patch-and-transform

kubectl apply -f xrd/definition.yaml
kubectl apply -f "xrd/composition-*"
wait_for_crds importclaims.crossplane.giantswarm.io
kubectl apply -f aws-claim.yaml
