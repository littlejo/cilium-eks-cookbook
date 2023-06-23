# Use case

* Install cilium on eks clusters with kube-proxy free
* ipam mode: eni

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md#cluster-installation)

# Cilium installation

## Patch

```
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system delete cm kube-proxy
kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
```

## Find eks endpoint and install

```
aws eks describe-cluster --name basic-cilium | jq -r .cluster.endpoint
https://29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
API_SERVER_IP=29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
API_SERVER_PORT=443
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.13.4 \
                                  --namespace kube-system \
                                  --set eni.enabled=true \
                                  --set ipam.mode=eni \
                                  --set egressMasqueradeInterfaces=eth0 \
                                  --set kubeProxyReplacement=strict \
                                  --set tunnel=disabled \
                                  --set k8sServiceHost=${API_SERVER_IP} \
                                  --set k8sServicePort=${API_SERVER_PORT}
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
Image versions    cilium             quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.4@sha256:c6bde19bbfe1483577f9ef375ff6de19402ac20277c451fe05729fcb9bc02a84: 2
```

## Check

```
kubectl -n kube-system exec ds/cilium -- cilium status | grep KubeProxyReplacement
KubeProxyReplacement:                          Strict   [eth0 192.168.27.176 (Direct Routing), eth1 192.168.18.89]
```

# Test

> cilium connectivity test
