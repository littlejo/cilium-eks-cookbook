# Use case

* Install cilium with aws eni prefix delegation 
  * Use less AWS ENI by pods
  * To be out of limits of ENI per node

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md)

# Cilium installation

> cilium install --helm-set "eni.awsEnablePrefixDelegation=true"
```
🔮 Auto-detected Kubernetes kind: EKS
ℹ️  Using Cilium version 1.13.3
🔮 Auto-detected cluster name: basic-cilium-us-east-1-eksctl-io
🔮 Auto-detected datapath mode: aws-eni
🔮 Auto-detected kube-proxy has been installed
🔥 Patching the "aws-node" DaemonSet to evict its pods...
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.13.3 --set cluster.id=0,cluster.name=basic-cilium-us-east-1-eksctl-io,egressMasqueradeInterfaces=eth0,encryption.nodeEncryption=false,eni.awsEnablePrefixDelegation=true,eni.enabled=true,ipam.mode=eni,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=disabled
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
Image versions    cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.3@sha256:394c40d156235d3c2004f77bb73402457092351cc6debdbc5727ba36fbd863ae: 1
```

Now you need to create new ec2 instance to apply prefix delegation. So i create another managed node group and i remove the old one:

```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: basic-cilium
  region: us-east-1
  version: "1.27"

managedNodeGroups:
- name: ng-2
  instanceType: t3.medium
  # taint nodes so that application pods are
  # not scheduled/executed until Cilium is deployed.
  # Alternatively, see the note above regarding taint effects.
  taints:
   - key: "node.cilium.io/agent-not-ready"
     value: "true"
     effect: "NoExecute"
  maxPodsPerNode: 110
```

* You can note the option maxPodsPerNode to increase the number of pods per node (to be out of limit of number of eni).

```
eksctl create nodegroup -f files/eks-cilium-prefix.yaml
eksctl delete nodegroup --cluster basic-cilium --name ng-1
```

# Test

What is the limit of t3.medium of pods per node: [eni-max-pod](https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt)
=> 17

```
kubectl create deployment nginx --image nginx --replicas 100
```

After some minutes, you can see:

```
kubectl get deployment
NAME    READY     UP-TO-DATE   AVAILABLE   AGE
nginx   100/100   100          100         2m12s
```

So you can have more than 34 pods on 2 nodes.
