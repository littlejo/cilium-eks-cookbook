# Use case

* Install cilium on eks clusters using IPv6 instead of IPv4
* Doesn't support eni (https://github.com/cilium/cilium/issues/18405)

# Requirements

* eksctl (tested version: 0.143.0)
* kubectl
* cilium cli
* aws-iam-authenticator

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
  name: ipv6-cilium
  region: us-east-1
  version: "1.27"

availabilityZones: ['us-east-1a', 'us-east-1b']

kubernetesNetworkConfig:
  ipFamily: IPv6

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy

iam:
  withOIDC: true

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

> eksctl create cluster -f ./files/eks-cilium-ipv6.yaml


# Cilium installation

> kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.13.3 \
  --namespace kube-system \
  --set ipv6.enabled=true \
  --set egressMasqueradeInterfaces=eth0


Restart pods :

> kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -L 1 kubectl delete pod

# Test

```
cilium status
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
Image versions    cilium-operator    quay.io/cilium/operator-generic:v1.13.3@sha256:fa7003cbfdf8358cb71786afebc711b26e5e44a2ed99bd4944930bba915b8910: 2
                  cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
```

> cilium connectivity test
