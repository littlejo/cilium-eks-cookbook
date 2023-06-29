# Use case

* Deploy cilium on eks clusters with argocd
* ipam: eni

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
  name: argo-cilium
  region: us-east-1
  version: "1.27"

managedNodeGroups:
- name: ng-1
  instanceType: t3.medium
  taints:
   - key: "node.cilium.io/agent-not-ready"
     value: "true"
     effect: "NoExecute"
- name: ng-2
  instanceType: t3.medium
```

* ng-2 is for argocd deployment

> eksctl create cluster -f ./files/eks-cilium-argo.yaml

> kubectl get node
```
NAME                             STATUS   ROLES    AGE     VERSION
ip-192-168-13-125.ec2.internal   Ready    <none>   3m34s   v1.27.1-eks-2f008fe
ip-192-168-13-211.ec2.internal   Ready    <none>   3m55s   v1.27.1-eks-2f008fe
ip-192-168-48-127.ec2.internal   Ready    <none>   3m53s   v1.27.1-eks-2f008fe
ip-192-168-58-192.ec2.internal   Ready    <none>   3m47s   v1.27.1-eks-2f008fe
```

# Argocd installation

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0-rc1/manifests/install.yaml
```

# Cilium installation

> kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cilium-cd
spec:
  destination:
    name: ''
    namespace: argocd
    server: 'https://kubernetes.default.svc'
  source:
    path: aws-eni
    repoURL: 'https://github.com/littlejo/argocd-cilium'
    targetRevision: main
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

> kubectl apply -f files/cilium-argocd.yaml -n argocd


> eksctl delete nodegroup ng-2 --cluster argo-cilium

> cilium status --wait
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

DaemonSet         cilium             Desired: 2, Ready: 2/2, Available: 2/2
Deployment        cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
Containers:       cilium             Running: 2
                  cilium-operator    Running: 2
Cluster Pods:     9/9 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.4@sha256:c6bde19bbfe1483577f9ef375ff6de19402ac20277c451fe05729fcb9bc02a84: 2
```

# Test

> cilium connectivity test
