# Use case

* Create a "link" between security group and network policy using cilium
* ipam mode: eni

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)
* [terraform](tools/terraform.txt)

# Cluster installation

exactly the same as install-cilium-eks.md

# Cilium installation

exactly the same as install-cilium-eks.md

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
