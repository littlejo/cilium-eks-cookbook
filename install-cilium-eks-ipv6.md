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

```
kubectl get svc -A
NAMESPACE     NAME              TYPE        CLUSTER-IP            EXTERNAL-IP   PORT(S)          AGE
cilium-test   echo-other-node   NodePort    fd36:eaee:439::cd0c   <none>        8080:30166/TCP   52m
cilium-test   echo-same-node    NodePort    fd36:eaee:439::9de    <none>        8080:30530/TCP   52m
default       kubernetes        ClusterIP   fd36:eaee:439::1      <none>        443/TCP          65m
kube-system   hubble-peer       ClusterIP   fd36:eaee:439::2113   <none>        443/TCP          53m
kube-system   kube-dns          ClusterIP   fd36:eaee:0439::a     <none>        53/UDP,53/TCP    65m
```

```
kubectl get pod -o wide -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE   IP                                        NODE                             NOMINATED NODE   READINESS GATES
cilium-test   client-6965d549d5-9pg8l               1/1     Running   0          53m   fd00::84                                  ip-192-168-23-163.ec2.internal   <none>           <none>
cilium-test   client2-76f4d7c5bc-vm2v8              1/1     Running   0          53m   fd00::81                                  ip-192-168-23-163.ec2.internal   <none>           <none>
cilium-test   echo-external-node-545d98c9b4-566xg   0/1     Pending   0          53m   <none>                                    <none>                           <none>           <none>
cilium-test   echo-other-node-545c9b778b-4bzdw      2/2     Running   0          53m   fd00::18c                                 ip-192-168-61-94.ec2.internal    <none>           <none>
cilium-test   echo-same-node-965bbc7d4-qn868        2/2     Running   0          53m   fd00::9f                                  ip-192-168-23-163.ec2.internal   <none>           <none>
cilium-test   host-netns-mdvln                      1/1     Running   0          53m   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   ip-192-168-61-94.ec2.internal    <none>           <none>
cilium-test   host-netns-n2km9                      1/1     Running   0          53m   2600:1f10:400b:9c00:7373:c69e:2aad:da3d   ip-192-168-23-163.ec2.internal   <none>           <none>
default       iptables-test                         1/1     Running   0          39m   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   ip-192-168-61-94.ec2.internal    <none>           <none>
default       nginx                                 1/1     Running   0          51m   fd00::137                                 ip-192-168-61-94.ec2.internal    <none>           <none>
kube-system   cilium-jgg2q                          1/1     Running   0          54m   2600:1f10:400b:9c00:7373:c69e:2aad:da3d   ip-192-168-23-163.ec2.internal   <none>           <none>
kube-system   cilium-nrtgj                          1/1     Running   0          54m   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   ip-192-168-61-94.ec2.internal    <none>           <none>
kube-system   cilium-operator-85c44f5b6b-t9zwd      1/1     Running   0          54m   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   ip-192-168-61-94.ec2.internal    <none>           <none>
kube-system   cilium-operator-85c44f5b6b-zq7h6      1/1     Running   0          54m   2600:1f10:400b:9c00:7373:c69e:2aad:da3d   ip-192-168-23-163.ec2.internal   <none>           <none>
kube-system   coredns-79df7fff65-pbn4h              1/1     Running   0          54m   fd00::110                                 ip-192-168-61-94.ec2.internal    <none>           <none>
kube-system   coredns-79df7fff65-xxrwg              1/1     Running   0          54m   fd00::54                                  ip-192-168-23-163.ec2.internal   <none>           <none>
kube-system   kube-proxy-rhhlq                      1/1     Running   0          57m   2600:1f10:400b:9c00:7373:c69e:2aad:da3d   ip-192-168-23-163.ec2.internal   <none>           <none>
kube-system   kube-proxy-w2qln                      1/1     Running   0          57m   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   ip-192-168-61-94.ec2.internal    <none>           <none>
```

```
kubectl get node -o wide
NAME                             STATUS   ROLES    AGE   VERSION               INTERNAL-IP                               EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-192-168-23-163.ec2.internal   Ready    <none>   58m   v1.27.1-eks-2f008fe   2600:1f10:400b:9c00:7373:c69e:2aad:da3d   <none>        Amazon Linux 2   5.10.179-168.710.amzn2.x86_64   containerd://1.6.19
ip-192-168-61-94.ec2.internal    Ready    <none>   58m   v1.27.1-eks-2f008fe   2600:1f10:400b:9c01:b557:7ec4:235c:5e59   <none>        Amazon Linux 2   5.10.179-168.710.amzn2.x86_64   containerd://1.6.19
```
