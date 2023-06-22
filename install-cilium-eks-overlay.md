# Use case

* Install cilium on eks clusters using IPv6 instead of IPv4
* Doesn't support eni (https://github.com/cilium/cilium/issues/18405)

# Requirements

* eksctl (minimum version: 0.143.0)
* kubectl
* cilium cli
* aws-iam-authenticator and aws cli
* helm

# Cluster installation

exactly the same as install-cilium-eks.md

# Cilium installation

launch:

```
kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.13.4 \
  --namespace kube-system \
  --set egressMasqueradeInterfaces=eth0
```

```
kubectl get node
NAME                             STATUS   ROLES    AGE     VERSION
ip-192-168-11-230.ec2.internal   Ready    <none>   8m41s   v1.27.1-eks-2f008fe
ip-192-168-59-196.ec2.internal   Ready    <none>   8m24s   v1.27.1-eks-2f008fe
```

# Test

## Long
cilium connectivity test

## Short
kubectl create ns cilium-test
kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/kubernetes/connectivity-check/connectivity-check.yaml

```
kubectl get pod -A -o wide
NAMESPACE     NAME                                                     READY   STATUS    RESTARTS   AGE   IP              NODE                            NOMINATED NODE   READINESS GATES
cilium-test   echo-a-6575c98b7d-th9ql                                  1/1     Running   0          32s   10.0.0.10       ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   echo-b-54b86d8976-vxsvl                                  1/1     Running   0          31s   10.0.1.169      ip-192-168-55-48.ec2.internal   <none>           <none>
cilium-test   echo-b-host-54d5cc5fcd-qjlbs                             1/1     Running   0          31s   192.168.55.48   ip-192-168-55-48.ec2.internal   <none>           <none>
cilium-test   host-to-b-multi-node-clusterip-846b574bbc-qj7zw          1/1     Running   0          29s   192.168.9.0     ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   host-to-b-multi-node-headless-5b4bf5459f-8lkzq           1/1     Running   0          29s   192.168.9.0     ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-a-6578dd7fbf-8qbjd                                1/1     Running   0          31s   10.0.0.66       ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-a-allowed-cnp-57fd79848c-9v9lf                    1/1     Running   0          30s   10.0.1.72       ip-192-168-55-48.ec2.internal   <none>           <none>
cilium-test   pod-to-a-denied-cnp-d984d7757-2p6mk                      1/1     Running   0          31s   10.0.0.90       ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-b-intra-node-nodeport-6654886dc9-g97j8            1/1     Running   0          29s   10.0.1.189      ip-192-168-55-48.ec2.internal   <none>           <none>
cilium-test   pod-to-b-multi-node-clusterip-54847b87b9-6k22l           1/1     Running   0          30s   10.0.0.214      ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-b-multi-node-headless-64b4d78855-bnqlz            1/1     Running   0          30s   10.0.0.193      ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-b-multi-node-nodeport-64757f6d5f-8jj57            1/1     Running   0          29s   10.0.0.49       ip-192-168-9-0.ec2.internal     <none>           <none>
cilium-test   pod-to-external-1111-76c448d975-k545p                    1/1     Running   0          31s   10.0.1.56       ip-192-168-55-48.ec2.internal   <none>           <none>
cilium-test   pod-to-external-fqdn-allow-google-cnp-56c545c6b9-lzhrv   1/1     Running   0          30s   10.0.0.246      ip-192-168-9-0.ec2.internal     <none>           <none>
kube-system   cilium-bg2rv                                             1/1     Running   0          14m   192.168.55.48   ip-192-168-55-48.ec2.internal   <none>           <none>
kube-system   cilium-operator-85c44f5b6b-nn6qb                         1/1     Running   0          14m   192.168.9.0     ip-192-168-9-0.ec2.internal     <none>           <none>
kube-system   cilium-operator-85c44f5b6b-zvf2q                         1/1     Running   0          14m   192.168.55.48   ip-192-168-55-48.ec2.internal   <none>           <none>
kube-system   cilium-pp4ml                                             1/1     Running   0          14m   192.168.9.0     ip-192-168-9-0.ec2.internal     <none>           <none>
kube-system   coredns-79df7fff65-5bmml                                 1/1     Running   0          45m   10.0.1.99       ip-192-168-55-48.ec2.internal   <none>           <none>
kube-system   coredns-79df7fff65-j4mbh                                 1/1     Running   0          45m   10.0.0.180      ip-192-168-9-0.ec2.internal     <none>           <none>
kube-system   kube-proxy-cqwqs                                         1/1     Running   0          16m   192.168.55.48   ip-192-168-55-48.ec2.internal   <none>           <none>
kube-system   kube-proxy-pxgrr                                         1/1     Running   0          16m   192.168.9.0     ip-192-168-9-0.ec2.internal     <none>           <none>
```

As you see pod (not created on daemonset) has range IPs is 10.0.0.0/16 and is different from range ips of vpc (192.168.0.0/16).
