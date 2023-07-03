# Use case

* You don't want to remove vpc cni but you want to use cilium network policy on eks clusters

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md#cluster-installation)

# Cilium installation

Version of vpc cni (minimum): v1.11.2

How to see:

```
kubectl -n kube-system get ds/aws-node -o json | jq -r '.spec.template.spec.containers[0].image'
XXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.12.6-eksbuild.2
```

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

