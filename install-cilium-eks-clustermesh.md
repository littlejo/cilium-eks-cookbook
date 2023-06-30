# Use case

* Install cilium on 2 eks clusters and communicate with clustermesh
* Terraform deployment
* ipam mode: eni

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)
* [terraform](tools/terraform.txt)

# Cluster installation 1

```
mkdir cluster1
cd cluster1
git clone https://github.com/littlejo/terraform-eks-cilium.git
cd terraform-eks-cilium
terraform init
terraform apply -var-file=clustermesh-1.tfvars
...
Plan: 49 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + update_kubeconfig = "aws eks update-kubeconfig --name cluster-mesh-cilium-1 --kubeconfig ~/.kube/config"

```

```
aws eks update-kubeconfig --name cluster-mesh-cilium-1 --kubeconfig ~/.kube/config
CONTEXT1=arn:aws:eks:us-east-1:xxxxxxxxxx:cluster/cluster-mesh-cilium-1
```

# Cluster installation 2

```
mkdir cluster2
cd cluster2
git clone https://github.com/littlejo/terraform-eks-cilium.git
cd terraform-eks-cilium
terraform init
terraform apply -var-file=clustermesh-2.tfvars
Plan: 49 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + update_kubeconfig = "aws eks update-kubeconfig --name cluster-mesh-cilium-2 --kubeconfig ~/.kube/config"
```

```
aws eks update-kubeconfig --name cluster-mesh-cilium-2 --kubeconfig ~/.kube/config
CONTEXT2=arn:aws:eks:us-east-1:xxxxxxxxxxxx:cluster/cluster-mesh-cilium-2
```

# VPC peering

You need create a vpc peering to communicate between LoadBalancer cluster mesh.

```
git clone https://github.com/littlejo/terraform-vpc-peering-example
cd terraform-vpc-peering-example
terraform init
terraform apply
```

# Cilium installation on cluster 1

## Patch

```
kubectl --context $CONTEXT1 -n kube-system delete ds kube-proxy
kubectl --context $CONTEXT1 -n kube-system delete cm kube-proxy
kubectl --context $CONTEXT1 -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
```

## Find eks endpoint and install

```
API_SERVER_IP=$(aws eks describe-cluster --name cluster-mesh-cilium-1 | jq -r .cluster.endpoint | awk -F/ '{print $3}')
API_SERVER_PORT=443
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --kube-context $CONTEXT1 \
                                  --version 1.13.4 \
                                  --namespace kube-system \
                                  --set eni.enabled=true \
                                  --set ipam.mode=eni \
                                  --set egressMasqueradeInterfaces=eth0 \
                                  --set kubeProxyReplacement=strict \
                                  --set tunnel=disabled \
                                  --set k8sServiceHost=${API_SERVER_IP} \
                                  --set k8sServicePort=${API_SERVER_PORT} \
                                  --set cluster.name=cluster-mesh-cilium-1 \
                                  --set cluster.id=1 \
                                  --set encryption.enabled=true \
                                  --set encryption.type=wireguard \
                                  --set l7Proxy=false
```

> cilium status --context $CONTEXT1 --wait

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium             Desired: 2, Ready: 2/2, Available: 2/2
Containers:       cilium             Running: 2
                  cilium-operator    Running: 1
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.3@sha256:394c40d156235d3c2004f77bb73402457092351cc6debdbc5727ba36fbd863ae: 1
```

```
kubectl --context $CONTEXT1 get secret -n kube-system cilium-ca -o yaml > cilium-ca.yaml
kubectl --context $CONTEXT1 get secret -n kube-system hubble-ca-secret -o yaml > hubble-ca-secret.yaml
```

# Cilium installation on cluster 2

## Patch

```
kubectl --context $CONTEXT2 -n kube-system delete ds kube-proxy
kubectl --context $CONTEXT2 -n kube-system delete cm kube-proxy
kubectl --context $CONTEXT2 -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
```

## Apply secrets from cluster 1

```
kubectl --context $CONTEXT2 apply -f cilium-ca.yaml
kubectl --context $CONTEXT2 apply -f hubble-ca-secret.yaml
```

## Find eks endpoint and install

```
API_SERVER_IP=$(aws eks describe-cluster --name cluster-mesh-cilium-2 | jq -r .cluster.endpoint | awk -F/ '{print $3}')
API_SERVER_PORT=443
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --kube-context $CONTEXT2 \
                                  --version 1.13.4 \
                                  --namespace kube-system \
                                  --set eni.enabled=true \
                                  --set ipam.mode=eni \
                                  --set egressMasqueradeInterfaces=eth0 \
                                  --set kubeProxyReplacement=strict \
                                  --set tunnel=disabled \
                                  --set k8sServiceHost=${API_SERVER_IP} \
                                  --set k8sServicePort=${API_SERVER_PORT} \
                                  --set cluster.name=cluster-mesh-cilium-2 \
                                  --set cluster.id=2 \
                                  --set encryption.enabled=true \
                                  --set encryption.type=wireguard \
                                  --set l7Proxy=false
```

> cilium status --context $CONTEXT2 --wait


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

# clustermesh enable on cluster 1

```
cilium clustermesh enable --context $CONTEXT1
```

```
cilium status --context $CONTEXT1
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        OK

Deployment        cilium-operator          Desired: 2, Ready: 2/2, Available: 2/2
DaemonSet         cilium                   Desired: 2, Ready: 2/2, Available: 2/2
Deployment        clustermesh-apiserver    Desired: 1, Ready: 1/1, Available: 1/1
Containers:       cilium-operator          Running: 2
                  clustermesh-apiserver    Running: 1
                  cilium                   Running: 2
Cluster Pods:     6/6 managed by Cilium
Image versions    cilium                   quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
                  cilium-operator          quay.io/cilium/operator-aws:v1.13.4@sha256:c6bde19bbfe1483577f9ef375ff6de19402ac20277c451fe05729fcb9bc02a84: 2
                  clustermesh-apiserver    quay.io/coreos/etcd:v3.5.4: 1
                  clustermesh-apiserver    quay.io/cilium/clustermesh-apiserver:v1.13.4: 1

cilium clustermesh status --context $CONTEXT1
Hostname based ingress detected, trying to resolve it
Hostname resolved, using the found ip(s)
✅ Cluster access information is available:
  - 10.1.11.252:2379
  - 10.1.224.194:2379
✅ Service "clustermesh-apiserver" of type "LoadBalancer" found
🔌 Cluster Connections:
🔀 Global services: [ min:0 / avg:0.0 / max:0 ]
```

# clustermesh enable on cluster 2

```
cilium clustermesh enable --context $CONTEXT2
```

```
cilium status --context $CONTEXT2
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        OK

Deployment        clustermesh-apiserver    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium                   Desired: 2, Ready: 2/2, Available: 2/2
Deployment        cilium-operator          Desired: 2, Ready: 2/2, Available: 2/2
Containers:       cilium                   Running: 2
                  cilium-operator          Running: 2
                  clustermesh-apiserver    Running: 1
Cluster Pods:     4/4 managed by Cilium
Image versions    cilium                   quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
                  cilium-operator          quay.io/cilium/operator-aws:v1.13.4@sha256:c6bde19bbfe1483577f9ef375ff6de19402ac20277c451fe05729fcb9bc02a84: 2
                  clustermesh-apiserver    quay.io/coreos/etcd:v3.5.4: 1
                  clustermesh-apiserver    quay.io/cilium/clustermesh-apiserver:v1.13.4: 1
cilium clustermesh status --context $CONTEXT2
Hostname based ingress detected, trying to resolve it
Hostname resolved, using the found ip(s)
✅ Cluster access information is available:
  - 10.2.241.85:2379
  - 10.2.183.144:2379
✅ Service "clustermesh-apiserver" of type "LoadBalancer" found
🔌 Cluster Connections:
🔀 Global services: [ min:0 / avg:0.0 / max:0 ]
```

# Connect Clusters

> cilium clustermesh connect --context $CONTEXT1 --destination-context $CONTEXT2
```
✨ Extracting access information of cluster cluster-mesh-cilium-2...
🔑 Extracting secrets from cluster cluster-mesh-cilium-2...
⚠️  Service type NodePort detected! Service may fail when nodes are removed from the cluster!
ℹ️  Found ClusterMesh service IPs: [10.2.105.236]
✨ Extracting access information of cluster cluster-mesh-cilium-1...
🔑 Extracting secrets from cluster cluster-mesh-cilium-1...
⚠️  Service type NodePort detected! Service may fail when nodes are removed from the cluster!
ℹ️  Found ClusterMesh service IPs: [10.1.121.93]
✨ Connecting cluster arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-1 -> arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-2...
🔑 Secret cilium-clustermesh does not exist yet, creating it...
🔑 Patching existing secret cilium-clustermesh...
✨ Patching DaemonSet with IP aliases cilium-clustermesh...
✨ Connecting cluster arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-2 -> arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-1...
🔑 Secret cilium-clustermesh does not exist yet, creating it...
🔑 Patching existing secret cilium-clustermesh...
✨ Patching DaemonSet with IP aliases cilium-clustermesh...
✅ Connected cluster arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-1 and arn:aws:eks:us-east-1:621304841877:cluster/cluster-mesh-cilium-2!
```

# Check

```
cilium clustermesh status --context $CONTEXT1
Hostname based ingress detected, trying to resolve it
Hostname resolved, using the found ip(s)
✅ Cluster access information is available:
  - 10.1.11.252:2379
  - 10.1.224.194:2379
✅ Service "clustermesh-apiserver" of type "LoadBalancer" found
✅ All 2 nodes are connected to all clusters [min:1 / avg:1.0 / max:1]
🔌 Cluster Connections:
- cluster-mesh-cilium-2: 2/2 configured, 2/2 connected
🔀 Global services: [ min:4 / avg:4.0 / max:4 ]

cilium clustermesh status --context $CONTEXT2
Hostname based ingress detected, trying to resolve it
Hostname resolved, using the found ip(s)
✅ Cluster access information is available:
  - 10.2.183.144:2379
  - 10.2.241.85:2379
✅ Service "clustermesh-apiserver" of type "LoadBalancer" found
✅ All 2 nodes are connected to all clusters [min:1 / avg:1.0 / max:1]
🔌 Cluster Connections:
- cluster-mesh-cilium-1: 2/2 configured, 2/2 connected
🔀 Global services: [ min:4 / avg:4.0 / max:4 ]
```

# Automatised Test

> cilium connectivity test --context $CONTEXT1 --multi-cluster $CONTEXT2

# Manual Test

```
kubectl apply --context $CONTEXT1 -f https://raw.githubusercontent.com/cilium/cilium/1.13.1/examples/kubernetes/clustermesh/global-service-example/cluster1.yaml
kubectl apply --context $CONTEXT2 -f https://raw.githubusercontent.com/cilium/cilium/1.13.1/examples/kubernetes/clustermesh/global-service-example/cluster2.yaml

kubectl get service/rebel-base --context $CONTEXT2 -o json | jq .metadata.annotations
{
  "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"kind\":\"Service\",\"metadata\":{\"annotations\":{\"service.cilium.io/global\":\"true\"},\"name\":\"rebel-base\",\"namespace\":\"default\"},\"spec\":{\"ports\":[{\"port\":80}],\"selector\":{\"name\":\"rebel-base\"},\"type\":\"ClusterIP\"}}\n",
  "service.cilium.io/global": "true"
}
```

```
for i in $(seq 1 10)
do
kubectl --context $CONTEXT1 exec -ti deployment/x-wing -- curl rebel-base
done
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```

```
for i in $(seq 1 10)
do
kubectl --context $CONTEXT2 exec -ti deployment/x-wing -- curl rebel-base
done
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```

* set affinity to local:
> kubectl --context=$CONTEXT1 annotate service rebel-base service.cilium.io/affinity=local --overwrite

```
for i in $(seq 1 10)
do
kubectl --context $CONTEXT1 exec -ti deployment/x-wing -- curl rebel-base
done
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
```

> kubectl --context $CONTEXT1 scale --replicas=0 deploy/rebel-base

```
for i in $(seq 1 10)
do
kubectl --context $CONTEXT1 exec -ti deployment/x-wing -- curl rebel-base
done
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```

> kubectl --context $CONTEXT1 scale --replicas=2 deploy/rebel-base
