# Use case

* Install cilium with ipsec encryption enabled on eks clusters

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md)

# Cilium installation

```
PSK=($(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64))
kubectl create -n kube-system secret generic cilium-ipsec-keys \
    --from-literal=keys="3 rfc4106(gcm(aes)) $PSK 128"
```

> cilium install --encryption ipsec

```
🔮 Auto-detected Kubernetes kind: EKS
ℹ️  Using Cilium version 1.13.3
🔮 Auto-detected cluster name: basic-cilium-us-east-1-eksctl-io
🔮 Auto-detected datapath mode: aws-eni
🔮 Auto-detected kube-proxy has been installed
🔥 Patching the "aws-node" DaemonSet to evict its pods...
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.13.3 --set cluster.id=0,cluster.name=basic-cilium-us-east-1-eksctl-io,egressMasqueradeInterfaces=eth0,encryption.enabled=true,encryption.nodeEncryption=false,encryption.type=ipsec,eni.enabled=true,ipam.mode=eni,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=disabled
ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
🔑 Created CA in secret cilium-ca
🔑 Generating certificates for Hubble...
🚀 Creating Service accounts...
🚀 Creating Cluster roles...
🔑 Found existing encryption secret cilium-ipsec-keys
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
Containers:       cilium             Running: 2
                  cilium-operator    Running: 1
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.3@sha256:394c40d156235d3c2004f77bb73402457092351cc6debdbc5727ba36fbd863ae: 1

cilium config view | grep enable-ipsec
enable-ipsec                               true
```

# Rotate your key

```
read KEYID ALGO PSK KEYSIZE < <(kubectl get secret -n kube-system cilium-ipsec-keys -o go-template='{{.data.keys | base64decode}}')
NEW_PSK=($(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64))
data=$(echo "{\"stringData\":{\"keys\":\"$((($KEYID+1))) "rfc4106\(gcm\(aes\)\)" $NEW_PSK 128\"}}")
kubectl patch secret -n kube-system cilium-ipsec-keys -p="${data}" -v=1
```

# Test

> cilium connectivity test

# More infos

https://isovalent.com/blog/post/tutorial-transparent-encryption-with-ipsec-and-wireguard/
