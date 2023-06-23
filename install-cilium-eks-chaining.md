# Use case

* Install eks clusters
* Install cilium on eks clusters

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

```
export AWS_DEFAULT_REGION=ch-ange-1
export AWS_ACCESS_KEY_ID="CHANGEME"
export AWS_SECRET_ACCESS_KEY="CHANGEME"
```

> source ./files/env

```yaml:
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: basic-cilium
  region: us-east-1
  version: "1.27"

managedNodeGroups:
- name: ng-1
  instanceType: t3.medium
  # taint nodes so that application pods are
  # not scheduled/executed until Cilium is deployed.
  # Alternatively, see the note above regarding taint effects.
  taints:
   - key: "node.cilium.io/agent-not-ready"
     value: "true"
     effect: "NoExecute"
```

> eksctl create cluster -f ./files/eks-cilium.yaml

> kubectl get node
```
NAME                             STATUS   ROLES    AGE     VERSION
ip-192-168-11-135.ec2.internal   Ready    <none>   4m18s   v1.27.1-eks-2f008fe
ip-192-168-56-129.ec2.internal   Ready    <none>   4m22s   v1.27.1-eks-2f008fe
```

# Cilium installation

Version of vpc cni: v1.11.2 >

> kubectl -n kube-system get ds/aws-node -o json | jq -r '.spec.template.spec.containers[0].image'
602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.12.6-eksbuild.2

```
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.13.4 \
                                  --namespace kube-system \
                                  --set cni.chainingMode=aws-cni \
                                  --set cni.exclusive=false \
                                  --set enableIPv4Masquerade=false \
                                  --set tunnel=disabled \
                                  --set endpointRoutes.enabled=true
```

If you have already pod launched on you cluster:
```
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
     ceps=$(kubectl -n "${ns}" get cep \
         -o jsonpath='{.items[*].metadata.name}')
     pods=$(kubectl -n "${ns}" get pod \
         -o custom-columns=NAME:.metadata.name,NETWORK:.spec.hostNetwork \
         | grep -E '\s(<none>|false)' | awk '{print $1}' | tr '\n' ' ')
     ncep=$(echo "${pods} ${ceps}" | tr ' ' '\n' | sort | uniq -u | paste -s -d ' ' -)
     for pod in $(echo $ncep); do
       echo "${ns}/${pod}";
     done
done
```

> cilium status --wait

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment        cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
DaemonSet         cilium             Desired: 2, Ready: 2/2, Available: 2/2
Containers:       cilium             Running: 2
                  cilium-operator    Running: 2
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium-operator    quay.io/cilium/operator-generic:v1.13.4@sha256:09ab77d324ef4d31f7d341f97ec5a2a4860910076046d57a2d61494d426c6301: 2
                  cilium             quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
```

# Test

> cilium connectivity test

# Create a security group for pods

It's not possible with t3 instance family:
https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html

so i can't do it.
All information are here: https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/

