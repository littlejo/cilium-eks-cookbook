# Use case

* Install cilium on eks clusters with kube-proxy free
* ipam mode: eni

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md#cluster-installation)

* i added to sg of nodegroup ec2 all traffic access rule from 0.0.0.0/0

# Cilium installation

## Patch

```
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system delete cm kube-proxy
kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
```

## Find eks endpoint and install

```
aws eks describe-cluster --name basic-cilium | jq -r .cluster.endpoint
https://92E99371B87ECA152191821C3596B241.gr7.us-east-1.eks.amazonaws.com
API_SERVER_IP=92E99371B87ECA152191821C3596B241.gr7.us-east-1.eks.amazonaws.com
API_SERVER_PORT=443

helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.13.4 \
                                  --namespace kube-system \
                                  --set eni.enabled=true \
                                  --set ipam.mode=eni \
                                  --set egressMasqueradeInterfaces=eth0 \
                                  --set kubeProxyReplacement=strict \
                                  --set tunnel=disabled \
                                  --set hubble.enabled=true \
                                  --set hubble.relay.enabled=true \
                                  --set hubble.ui.enabled=true \
                                  --set k8sServiceHost=${API_SERVER_IP} \
                                  --set k8sServicePort=${API_SERVER_PORT}
```

> cilium status --wait

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

Deployment        cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
Deployment        hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Deployment        hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium             Desired: 2, Ready: 2/2, Available: 2/2
Containers:       hubble-ui          Running: 1
                  hubble-relay       Running: 1
                  cilium             Running: 2
                  cilium-operator    Running: 2
Cluster Pods:     4/4 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 2
                  cilium-operator    quay.io/cilium/operator-aws:v1.13.4@sha256:c6bde19bbfe1483577f9ef375ff6de19402ac20277c451fe05729fcb9bc02a84: 2
                  hubble-ui          quay.io/cilium/hubble-ui:v0.11.0@sha256:bcb369c47cada2d4257d63d3749f7f87c91dde32e010b223597306de95d1ecc8: 1
                  hubble-ui          quay.io/cilium/hubble-ui-backend:v0.11.0@sha256:14c04d11f78da5c363f88592abae8d2ecee3cbe009f443ef11df6ac5f692d839: 1
                  hubble-relay       quay.io/cilium/hubble-relay:v1.13.4@sha256:bac057a5130cf75adf5bc363292b1f2642c0c460ac9ff018fcae3daf64873871: 1

```

## Test


> hubble ...

```
kubectl exec -it ds/cilium -n kube-system -c cilium-agent -- cilium status
KVStore:                 Ok   Disabled
Kubernetes:              Ok   1.27+ (v1.27.3-eks-a5565ad) [linux/amd64]
Kubernetes APIs:         ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:    Strict   [eth0 192.168.7.5 (Direct Routing)]
Host firewall:           Disabled
CNI Chaining:            none
CNI Config file:         CNI configuration file management disabled
Cilium:                  Ok   1.13.4 (v1.13.4-4061cdfc)
NodeMonitor:             Listening for events on 2 CPUs with 64x4096 of shared memory
Cilium health daemon:    Ok
IPAM:                    IPv4: 6/15 allocated,
IPv6 BIG TCP:            Disabled
BandwidthManager:        Disabled
Host Routing:            Legacy
Masquerading:            IPTables [IPv4: Enabled, IPv6: Disabled]
Controller Status:       35/35 healthy
Proxy Status:            OK, ip 192.168.7.45, 0 redirects active on ports 10000-20000
Global Identity Range:   min 256, max 65535
Hubble:                  Ok   Current/Max Flows: 3058/4095 (74.68%), Flows/s: 10.57   Metrics: Disabled
Encryption:              Disabled
Cluster health:          2/2 reachable   (2023-07-22T04:58:04Z)
```

> cilium connectivity test

```
✅ All 42 tests (304 actions) successful, 12 tests skipped, 0 scenarios skipped.
```

## Workaround


* I backup the configmap:

```
kubectl get cm -n kube-system cilium-config -o yaml > cilium-config-origin.yaml
```

I changed:
```
diff -u cilium-config-origin.yaml cilium-config.yaml
--- cilium-config-origin.yaml	2023-07-22 05:22:08.303311094 +0000
+++ cilium-config.yaml	2023-07-22 05:23:41.211665878 +0000
@@ -1,5 +1,9 @@
 apiVersion: v1
 data:
+  devices: "eth+"
+  enable-bpf-masquerade: "true"
+  ipv4-native-routing-cidr: "192.168.0.0/16"
+  enable-host-legacy-routing: "false"
   agent-not-ready-taint-key: node.cilium.io/agent-not-ready
   arping-refresh-period: 30s
   auto-create-cilium-node-resource: "true"
@@ -21,12 +25,11 @@
   disable-cnp-status-updates: "true"
   disable-endpoint-crd: "false"
   ec2-api-endpoint: ""
-  egress-masquerade-interfaces: eth0
   enable-auto-protect-node-port-range: "true"
   enable-bgp-control-plane: "false"
   enable-bpf-clock-probe: "true"
   enable-endpoint-health-checking: "true"
-  enable-endpoint-routes: "true"
+  enable-endpoint-routes: "false"
   enable-health-check-nodeport: "true"
   enable-health-checking: "true"
   enable-hubble: "true"
```

* I apply this the configmap:

```
kubectl delete -f cilium-config-origin.yaml
kubectl apply -f cilium-config.yaml
```

```
kubectl rollout restart daemonset  -n kube-system cilium
kubectl rollout restart deployment -n kube-system cilium-operator
kubectl rollout restart deployment -n kube-system coredns
kubectl rollout restart deployment -n kube-system hubble-relay
kubectl delete namespace cilium-test
```

# Test

```
kubectl exec -it ds/cilium -n kube-system -c cilium-agent -- cilium status
KVStore:                 Ok   Disabled
Kubernetes:              Ok   1.27+ (v1.27.3-eks-a5565ad) [linux/amd64]
Kubernetes APIs:         ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:    Strict   [eth0 192.168.7.5 (Direct Routing), eth1 192.168.22.217, eth2 192.168.31.188]
Host firewall:           Disabled
CNI Chaining:            none
CNI Config file:         CNI configuration file management disabled
Cilium:                  Ok   1.13.4 (v1.13.4-4061cdfc)
NodeMonitor:             Listening for events on 2 CPUs with 64x4096 of shared memory
Cilium health daemon:    Ok
IPAM:                    IPv4: 4/15 allocated,
IPv6 BIG TCP:            Disabled
BandwidthManager:        Disabled
Host Routing:            BPF
Masquerading:            BPF   [eth0, eth1, eth2]   192.168.0.0/16 [IPv4: Enabled, IPv6: Disabled]
Controller Status:       29/29 healthy
Proxy Status:            OK, ip 192.168.7.45, 0 redirects active on ports 10000-20000
Global Identity Range:   min 256, max 65535
Hubble:                  Ok   Current/Max Flows: 2327/4095 (56.83%), Flows/s: 10.75   Metrics: Disabled
Encryption:              Disabled
Cluster health:          2/2 reachable   (2023-07-22T05:28:17Z)
```

> cilium connectivity test --sysdump-debug --test-namespace t1

```
📋 Test Report
❌ 10/42 tests failed (58/304 actions), 12 tests skipped, 0 scenarios skipped:
Test [no-policies]:
  ❌ no-policies/pod-to-host/ping-ipv4-3: t1/client-6965d549d5-94lpz (192.168.15.219) -> 54.81.30.178 (54.81.30.178:0)
  ❌ no-policies/pod-to-host/ping-ipv4-5: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> 54.81.30.178 (54.81.30.178:0)
Test [allow-all-except-world]:
  ❌ allow-all-except-world/pod-to-service/curl-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> t1/echo-other-node (echo-other-node:8080)
  ❌ allow-all-except-world/pod-to-service/curl-1: t1/client-6965d549d5-94lpz (192.168.15.219) -> t1/echo-same-node (echo-same-node:8080)
  ❌ allow-all-except-world/pod-to-service/curl-2: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-other-node (echo-other-node:8080)
  ❌ allow-all-except-world/pod-to-service/curl-3: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-same-node (echo-same-node:8080)
  ❌ allow-all-except-world/pod-to-host/ping-ipv4-1: t1/client-6965d549d5-94lpz (192.168.15.219) -> 54.81.30.178 (54.81.30.178:0)
  ❌ allow-all-except-world/pod-to-host/ping-ipv4-5: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> 54.81.30.178 (54.81.30.178:0)
Test [host-entity]:
  ❌ host-entity/pod-to-host/ping-ipv4-3: t1/client-6965d549d5-94lpz (192.168.15.219) -> 54.81.30.178 (54.81.30.178:0)
  ❌ host-entity/pod-to-host/ping-ipv4-5: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> 54.81.30.178 (54.81.30.178:0)
Test [echo-ingress-l7]:
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-2-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-2-public (192.168.36.39:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-2-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-2-private (192.168.36.39:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-2-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-2-privatewith-header (192.168.36.39:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-3-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-3-public (192.168.18.47:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-3-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-3-private (192.168.18.47:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-3-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-3-privatewith-header (192.168.18.47:8080)
Test [echo-ingress-l7-named-port]:
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-0-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-0-public (192.168.36.39:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-0-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-0-private (192.168.36.39:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-0-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-0-privatewith-header (192.168.36.39:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-1-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-public (192.168.18.47:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-1-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-private (192.168.18.47:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-1-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-privatewith-header (192.168.18.47:8080)
Test [client-egress-l7-method]:
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-public (192.168.18.47:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-private (192.168.18.47:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-privatewith-header (192.168.18.47:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-public: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-public (192.168.36.39:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-private: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-private (192.168.36.39:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-privatewith-header: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> curl-ipv4-1-privatewith-header (192.168.36.39:8080)
Test [client-egress-l7]:
  ❌ client-egress-l7/pod-to-pod/curl-ipv4-2: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-other-node-66bdd89578-phzxz (192.168.36.39:8080)
  ❌ client-egress-l7/pod-to-pod/curl-ipv4-3: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-same-node-55db76dd44-ckhch (192.168.18.47:8080)
  ❌ client-egress-l7/pod-to-world/http-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-http (one.one.one.one:80)
  ❌ client-egress-l7/pod-to-world/https-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https (one.one.one.one:443)
  ❌ client-egress-l7/pod-to-world/https-to-one.one.one.one-index-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https-index (one.one.one.one:443)
  ❌ client-egress-l7/pod-to-world/http-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-http (one.one.one.one:80)
  ❌ client-egress-l7/pod-to-world/https-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https (one.one.one.one:443)
  ❌ client-egress-l7/pod-to-world/https-to-one.one.one.one-index-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https-index (one.one.one.one:443)
Test [client-egress-l7-named-port]:
  ❌ client-egress-l7-named-port/pod-to-pod/curl-ipv4-2: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-same-node-55db76dd44-ckhch (192.168.18.47:8080)
  ❌ client-egress-l7-named-port/pod-to-pod/curl-ipv4-3: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> t1/echo-other-node-66bdd89578-phzxz (192.168.36.39:8080)
  ❌ client-egress-l7-named-port/pod-to-world/http-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-http (one.one.one.one:80)
  ❌ client-egress-l7-named-port/pod-to-world/https-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https (one.one.one.one:443)
  ❌ client-egress-l7-named-port/pod-to-world/https-to-one.one.one.one-index-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https-index (one.one.one.one:443)
  ❌ client-egress-l7-named-port/pod-to-world/http-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-http (one.one.one.one:80)
  ❌ client-egress-l7-named-port/pod-to-world/https-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https (one.one.one.one:443)
  ❌ client-egress-l7-named-port/pod-to-world/https-to-one.one.one.one-index-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https-index (one.one.one.one:443)
Test [dns-only]:
  ❌ dns-only/pod-to-world/http-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-http (one.one.one.one:80)
  ❌ dns-only/pod-to-world/https-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https (one.one.one.one:443)
  ❌ dns-only/pod-to-world/https-to-one.one.one.one-index-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https-index (one.one.one.one:443)
  ❌ dns-only/pod-to-world/http-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-http (one.one.one.one:80)
  ❌ dns-only/pod-to-world/https-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https (one.one.one.one:443)
  ❌ dns-only/pod-to-world/https-to-one.one.one.one-index-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https-index (one.one.one.one:443)
Test [to-fqdns]:
  ❌ to-fqdns/pod-to-world/http-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-http (one.one.one.one:80)
  ❌ to-fqdns/pod-to-world/https-to-one.one.one.one-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https (one.one.one.one:443)
  ❌ to-fqdns/pod-to-world/https-to-one.one.one.one-index-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> one.one.one.one-https-index (one.one.one.one:443)
  ❌ to-fqdns/pod-to-world/http-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-http (one.one.one.one:80)
  ❌ to-fqdns/pod-to-world/https-to-one.one.one.one-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https (one.one.one.one:443)
  ❌ to-fqdns/pod-to-world/https-to-one.one.one.one-index-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> one.one.one.one-https-index (one.one.one.one:443)
  ❌ to-fqdns/pod-to-world-2/https-cilium-io-0: t1/client-6965d549d5-94lpz (192.168.15.219) -> cilium-io-https (cilium.io:443)
  ❌ to-fqdns/pod-to-world-2/https-cilium-io-1: t1/client2-76f4d7c5bc-5b2jc (192.168.24.162) -> cilium-io-https (cilium.io:443)
connectivity test failed: 10 tests failed
```
