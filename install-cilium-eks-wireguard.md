# Use case

* Install cilium with wireguard encryption enabled on eks clusters

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md)

# Cilium installation

> cilium install --encryption wireguard

```
🔮 Auto-detected Kubernetes kind: EKS
ℹ️  Using Cilium version 1.13.3
🔮 Auto-detected cluster name: basic-cilium-us-east-1-eksctl-io
ℹ️  L7 proxy disabled due to Wireguard encryption
🔮 Auto-detected datapath mode: aws-eni
🔮 Auto-detected kube-proxy has been installed
ℹ️  L7 proxy disabled due to Wireguard encryption
🔥 Patching the "aws-node" DaemonSet to evict its pods...
ℹ️  L7 proxy disabled due to Wireguard encryption
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.13.3 --set cluster.id=0,cluster.name=basic-cilium-us-east-1-eksctl-io,egressMasqueradeInterfaces=eth0,encryption.enabled=true,encryption.nodeEncryption=false,encryption.type=wireguard,eni.enabled=true,ipam.mode=eni,kubeProxyReplacement=disabled,l7Proxy=false,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=disabled
ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
🔑 Created CA in secret cilium-ca
🔑 Generating certificates for Hubble...
🚀 Creating Service accounts...
🚀 Creating Cluster roles...
🚀 Creating ConfigMap for Cilium version 1.13.3...
🚀 Creating Agent DaemonSet...
🚀 Creating Operator Deployment...
⌛ Waiting for Cilium to be installed and ready...
✅ Cilium was successfully installed! Run 'cilium status' to view installation health
```

```
cilium status --wait
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium             Desired: 2, Ready: 2/2, Available: 2/2
Containers:       cilium-operator    Running: 1
                  cilium             Running: 2
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.3@sha256:394c40d156235d3c2004f77bb73402457092351cc6debdbc5727ba36fbd863ae: 1
```

```
kubectl get ciliumnodes
NAME                             CILIUMINTERNALIP   INTERNALIP       AGE
ip-192-168-20-215.ec2.internal   192.168.19.240     192.168.20.215   2m50s
ip-192-168-50-79.ec2.internal    192.168.62.252     192.168.50.79    2m50s
```

```
kubectl get ciliumnodes ip-192-168-50-79.ec2.internal -o json | jq .metadata.annotations
{
  "network.cilium.io/wg-pub-key": "HMfZu016CF/0EYMl0tACI3qeaT2TePs831EfJZmzdQw="
}
kubectl exec -n kube-system -ti ds/cilium -- cilium status |grep Encryption
Encryption:              Wireguard       [cilium_wg0 (Pubkey: HMfZu016CF/0EYMl0tACI3qeaT2TePs831EfJZmzdQw=, Port: 51871, Peers: 1)]
```

* you can see cilium_wg0:
```
kubectl exec -n kube-system -ti ds/cilium -- ip link |grep cilium
Defaulted container "cilium-agent" out of: cilium-agent, config (init), mount-cgroup (init), apply-sysctl-overwrites (init), mount-bpf-fs (init), clean-cilium-state (init), install-cni-binaries (init)
3: cilium_wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 8921 qdisc noqueue state UNKNOWN mode DEFAULT group default
5: cilium_net@cilium_host: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default qlen 1000
6: cilium_host@cilium_net: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 62:ff:e0:48:bb:60 brd ff:ff:ff:ff:ff:ff link-netns cilium-health
```

# Test

> cilium connectivity test
