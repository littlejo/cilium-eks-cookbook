# Use case

* Install dev version of cilium on eks clusters

# Requirements

* eksctl (tested version: 0.143.0)
* kubectl
* cilium cli
* aws-iam-authenticator

# Cluster installation

exactly the same as install-cilium-eks.md

# Cilium installation

> cilium install --version=v1.14.0-snapshot.3
```
🔮 Auto-detected Kubernetes kind: EKS
ℹ️  Using Cilium version 1.14.0-snapshot.3
🔮 Auto-detected cluster name: basic-cilium-us-east-1-eksctl-io
🔮 Auto-detected datapath mode: aws-eni
🔮 Auto-detected kube-proxy has been installed
🔥 Patching the "aws-node" DaemonSet to evict its pods...
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.14.0-snapshot.3 --set cluster.id=0,cluster.name=basic-cilium-us-east-1-eksctl-io,egressMasqueradeInterfaces=eth0,encryption.nodeEncryption=false,eni.enabled=true,ipam.mode=eni,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=disabled
ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
🔑 Created CA in secret cilium-ca
🔑 Generating certificates for Hubble...
🚀 Creating Service accounts...
🚀 Creating Cluster roles...
🚀 Creating ConfigMap for Cilium version 1.14.0-snapshot.3...
🚀 Creating Agent DaemonSet...
🚀 Creating Operator Deployment...
⌛ Waiting for Cilium to be installed and ready...
✅ Cilium was successfully installed! Run 'cilium status' to view installation health
```

> cilium status --wait

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
Image versions    cilium             quay.io/cilium/cilium:v1.14.0-snapshot.3: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.14.0-snapshot.3: 1
```

# Test

> cilium connectivity test
