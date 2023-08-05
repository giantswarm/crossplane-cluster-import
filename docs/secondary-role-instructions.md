# Creating the secondary role

For crossplane `provider-aws-*` to be able to interact with the cloud resource
we must create a role and bind this to the primary role created as part of the
crossplane provider install.

## Create the policy

Edit the file [`eks-import-crossplane-policy](../policies/eks-import-crossplane-policy.json)
and set the variable `${AWS_ACCOUNT_ID}` to the ID of the AWS account you're
going to use.

```bash
export POLICY_NAME="eks-import-crossplane-policy"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -rn .Account)

cat ./policies/${POLICY_NAME}.json | envsubst \
    | sponge ./policies/${POLICY_NAME}.json
```

Apply this policy to AWS

```bash
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://policies/${POLICY_NAME}.json \
    --description "Custom policy for assuming roles"
```

## Create the trust policy

Next, edit the trust policy file [eks-import-crossplane-role-trust-policy](../policies/eks-import-crossplane-role-trust-policy.json)
and set the following properties

- `AWS_ACCOUNT_ID` This is the account id for the account the MC is located inside
- `PARENT_ACCOUNT_ID` This is the account ID of the account containing the
  `MC_NAME-capa-controller` user
- `MC_NAME` This is the name of your management cluster

```bash
export PARENT_ACCOUNT_ID=1234567890
export MC_NAME=example
export TRUST_POLICY_NAME=eks-import-crossplane-role-trust-policy
cat ./policies/${TRUST_POLICY_NAME}.json | envsubst \
    | sponge ./policies/${TRUST_POLICY_NAME}.json
```

## Create the role

Now create the role and attach the policy to it.

```bash
ROLE_NAME=eks-import-crossplane-role
aws iam create-role --role-name ${ROLE_NAME} \
    --policy-document file://policies/${TRUST_POLICY_NAME}.json
aws iam attach-role-policy --policy-arn \
   "arn:aws:iam::aws:policy/${POLICY_NAME}" \
   --role-name ${ROLE_NAME}
```

## Update the crossplane-assume-role

If crossplane is already running on your management cluster, then inside your
AWS account you will find a role
[`crossplane-assume-role`](https://github.com/giantswarm/management-cluster-bases/blob/main/extras/crossplane/providers/upbound/aws/setting-up-irsa.md#setting-up-the-crossplane-assume-role).

You must add the `eks-import-crossplane-role` to this policies
`sts:AssumeRole` resources section in order for crossplane to be able to
assume the role.

```json
"Resource": [
    "arn:aws:iam::1234567890:role/rds-crossplane-role",
    "arn:aws:iam::1234567890:role/eks-import-crossplane-role"
]
```
