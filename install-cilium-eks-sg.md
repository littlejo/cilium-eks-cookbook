# Use case

* Install eks clusters
* Install cilium on eks clusters
* Create a "link" between security group and network policy

# Requirements

* eksctl (tested version: 0.143.0)
* kubectl
* cilium cli
* aws-iam-authenticator
* terraform

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

> cilium install
```
🔮 Auto-detected Kubernetes kind: EKS
ℹ️  Using Cilium version 1.13.3
🔮 Auto-detected cluster name: basic-cilium-us-east-1-eksctl-io
🔮 Auto-detected datapath mode: aws-eni
🔮 Auto-detected kube-proxy has been installed
🔥 Patching the "aws-node" DaemonSet to evict its pods...
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.13.3 --set cluster.id=0,cluster.name=basic-cilium-us-east-1-eksctl-io,egressMasqueradeInterfaces=eth0,encryption.nodeEncryption=false,eni.enabled=true,ipam.mode=eni,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=disabled
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
Containers:       cilium-operator    Running: 1
                  cilium             Running: 2
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.3@sha256:77176464a1e11ea7e89e984ac7db365e7af39851507e94f137dcf56c87746314: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.3@sha256:394c40d156235d3c2004f77bb73402457092351cc6debdbc5727ba36fbd863ae: 1
```

# Test

> cilium connectivity test

# Create EC2 with nginx installed and security group

I used terraform for that:

```
cd files/
terraform init
[...]
terraform apply
[...]
Outputs:

private_ip = "192.168.124.214"
security_group_id = "sg-0ce5e337befa5e3eb"
```

# Create network policy

## Deny all

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  egress: []
```

> kubectl apply -f np-deny-all.yaml

> kubectl get networkpolicy
```
NAME       POD-SELECTOR   AGE
deny-all   <none>         2m22s
```

### Test

```
kubectl run -it --image=alpine -- check
If you don't see a command prompt, try pressing enter.
/ # wget 192.168.124.214
Connecting to 192.168.124.214 (192.168.124.214:80)
wget: can't connect to remote host (192.168.124.214): Operation timed out
```

## security group egress access

```
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: egress-default
  namespace: default
spec:
  egress:
    - toGroups:
        - aws:
            securityGroupsIds:
              - sg-0ce5e337befa5e3eb
  endpointSelector: {}
```

* change sg-0ce5e337befa5e3eb by your own security group id

```
kubectl apply -f files/cnp-securitygroup.yaml
```

you see the network policy and the derivative policy:

```
kubectl get cnp
NAME                                                           AGE
egress-default                                                 3s
egress-default-togroups-b698c313-8f61-4f49-8d8a-0268259707b4   2s
```

* you refind the good egress ip (192.168.124.214):

```
kubectl describe cnp egress-default-togroups-b698c313-8f61-4f49-8d8a-0268259707b4
Name:         egress-default-togroups-b698c313-8f61-4f49-8d8a-0268259707b4
Namespace:    default
Labels:       io.cilium.network.policy.kind=derivative
              io.cilium.network.policy.parent.uuid=b698c313-8f61-4f49-8d8a-0268259707b4
Annotations:  <none>
API Version:  cilium.io/v2
Kind:         CiliumNetworkPolicy
Metadata:
  Creation Timestamp:  2023-06-15T14:58:50Z
  Generation:          1
  Owner References:
    API Version:     cilium.io/v2
    Kind:            CiliumNetworkPolicy
    Name:            egress-default
    UID:             b698c313-8f61-4f49-8d8a-0268259707b4
  Resource Version:  25612
  UID:               07bd59e0-0406-4f0e-9193-e595b8b926d1
Specs:
  Egress:
    To CIDR Set:
      Cidr:  192.168.124.214/32
  Endpoint Selector:
    Match Labels:
      k8s:io.kubernetes.pod.namespace:  default
  Labels:
    Key:     io.cilium.k8s.policy.derived-from
    Source:  k8s
    Value:   CiliumNetworkPolicy
    Key:     io.cilium.k8s.policy.name
    Source:  k8s
    Value:   egress-default
    Key:     io.cilium.k8s.policy.namespace
    Source:  k8s
    Value:   default
    Key:     io.cilium.k8s.policy.uid
    Source:  k8s
    Value:   b698c313-8f61-4f49-8d8a-0268259707b4
Events:      <none>
```

### Check

```
kubectl run -it --image=alpine -- work
If you don't see a command prompt, try pressing enter.
/ # wget 192.168.124.214
Connecting to 192.168.124.214 (192.168.124.214:80)
saving to 'index.html'
index.html           100% |****************************************************************************************************************************************************|   615  0:00:00 ETA
'index.html' saved
```