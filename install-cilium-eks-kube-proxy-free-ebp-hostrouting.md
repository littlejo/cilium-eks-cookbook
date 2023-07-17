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
https://29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
API_SERVER_IP=29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
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
                                  --set k8sServiceHost=${API_SERVER_IP} \
                                  --set k8sServicePort=${API_SERVER_PORT}
```

> cilium status --wait

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

## Workaround

```
kubectl -n kube-system exec ds/cilium -- cilium status | grep KubeProxyReplacement
KubeProxyReplacement:                          Strict   [eth0 192.168.27.176 (Direct Routing), eth1 192.168.18.89]
```

* I backup the configmap:

```
kubectl get cm -n kube-system cilium-config -o yaml > cilium-config-origin.yaml
```

* I apply this the configmap:

```
apiVersion: v1
data:
  devices: "eth+"  ### ADD
  enable-bpf-masquerade: "true" ### ADD
  ipv4-native-routing-cidr: "192.168.0.0/16"  ### ADD
  agent-not-ready-taint-key: node.cilium.io/agent-not-ready
  arping-refresh-period: 30s
  auto-create-cilium-node-resource: "true"
  auto-direct-node-routes: "false"
  bpf-lb-external-clusterip: "false"
  bpf-lb-map-max: "65536"
  bpf-lb-sock: "false"
  bpf-map-dynamic-size-ratio: "0.0025"
  bpf-policy-map-max: "16384"
  bpf-root: /sys/fs/bpf
  cgroup-root: /run/cilium/cgroupv2
  cilium-endpoint-gc-interval: 5m0s
  cluster-id: "0"
  cluster-name: default
  cni-uninstall: "true"
  custom-cni-conf: "false"
  debug: "false"
  debug-verbose: ""
  disable-cnp-status-updates: "true"
  disable-endpoint-crd: "false"
  ec2-api-endpoint: ""
  enable-auto-protect-node-port-range: "true"
  enable-bgp-control-plane: "false"
  enable-bpf-clock-probe: "true"
  enable-endpoint-health-checking: "true"
  enable-endpoint-routes: "false" ### CHANGE
  enable-health-check-nodeport: "true"
  enable-health-checking: "true"
  enable-hubble: "true"
  enable-ipv4: "true"
  enable-ipv4-masquerade: "true"
  enable-ipv6: "false"
  enable-ipv6-big-tcp: "false"
  enable-ipv6-masquerade: "false" ### CHANGE
  enable-k8s-terminating-endpoint: "true"
  enable-l2-neigh-discovery: "true"
  enable-l7-proxy: "true"
  enable-local-redirect-policy: "false"
  enable-policy: default
  enable-remote-node-identity: "true"
  enable-sctp: "false"
  enable-svc-source-range-check: "true"
  enable-vtep: "false"
  enable-well-known-identities: "false"
  enable-xt-socket-fallback: "true"
  eni-tags: '{}'
  hubble-disable-tls: "false"
  hubble-listen-address: :4244
  hubble-socket-path: /var/run/cilium/hubble.sock
  hubble-tls-cert-file: /var/lib/cilium/tls/hubble/server.crt
  hubble-tls-client-ca-files: /var/lib/cilium/tls/hubble/client-ca.crt
  hubble-tls-key-file: /var/lib/cilium/tls/hubble/server.key
  identity-allocation-mode: crd
  identity-gc-interval: 15m0s
  identity-heartbeat-timeout: 30m0s
  install-no-conntrack-iptables-rules: "false"
  ipam: eni
  kube-proxy-replacement: strict
  kube-proxy-replacement-healthz-bind-address: ""
  monitor-aggregation: medium
  monitor-aggregation-flags: all
  monitor-aggregation-interval: 5s
  node-port-bind-protection: "true"
  nodes-gc-interval: 5m0s
  operator-api-serve-addr: 127.0.0.1:9234
  preallocate-bpf-maps: "false"
  procfs: /host/proc
  remove-cilium-node-taints: "true"
  set-cilium-is-up-condition: "true"
  sidecar-istio-proxy-image: cilium/istio_proxy
  skip-cnp-status-startup-clean: "false"
  synchronize-k8s-nodes: "true"
  tofqdns-dns-reject-response-code: refused
  tofqdns-enable-dns-compression: "true"
  tofqdns-endpoint-max-ip-per-hostname: "50"
  tofqdns-idle-connection-grace-period: 0s
  tofqdns-max-deferred-connection-deletes: "10000"
  tofqdns-min-ttl: "3600"
  tofqdns-proxy-response-max-delay: 100ms
  tunnel: disabled
  unmanaged-pod-watcher-interval: "15"
  vtep-cidr: ""
  vtep-endpoint: ""
  vtep-mac: ""
  vtep-mask: ""
kind: ConfigMap
metadata:
  annotations:
    meta.helm.sh/release-name: cilium
    meta.helm.sh/release-namespace: kube-system
  creationTimestamp: "2023-07-13T09:13:06Z"
  labels:
    app.kubernetes.io/managed-by: Helm
  name: cilium-config
  namespace: kube-system
  resourceVersion: "1956"
  uid: 1f196454-6242-4e0c-bee1-54e31034f92e
```

```
kubectl delete -f cilium-config-origin.yaml
kubectl apply -f cilium-config.yaml
```

```
kubectl rollout -n kube-system restart ds/cilium
kubectl rollout restart deployment -n kube-system coredns
kubectl rollout restart deployment -n kube-system cilium-operator
```

# Test

> cilium connectivity test

```
📋 Test Report
❌ 9/42 tests failed (29/304 actions), 12 tests skipped, 0 scenarios skipped:
Test [no-policies]:
  ❌ no-policies/pod-to-host/ping-ipv4-1: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> 3.234.144.72 (3.234.144.72:0)
  ❌ no-policies/pod-to-host/ping-ipv4-7: cilium-test/client-6965d549d5-spvkn (192.168.31.107) -> 3.234.144.72 (3.234.144.72:0)
Test [allow-all-except-world]:
  ❌ allow-all-except-world/pod-to-service/curl-3: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> cilium-test/echo-same-node (echo-same-node:8080)
  ❌ allow-all-except-world/pod-to-host/ping-ipv4-1: cilium-test/client-6965d549d5-spvkn (192.168.31.107) -> 3.234.144.72 (3.234.144.72:0)
  ❌ allow-all-except-world/pod-to-host/ping-ipv4-5: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> 3.234.144.72 (3.234.144.72:0)
Test [host-entity]:
  ❌ host-entity/pod-to-host/ping-ipv4-1: cilium-test/client-6965d549d5-spvkn (192.168.31.107) -> 3.234.144.72 (3.234.144.72:0)
  ❌ host-entity/pod-to-host/ping-ipv4-5: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> 3.234.144.72 (3.234.144.72:0)
Test [echo-ingress-l7]:
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-2-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-2-public (192.168.60.196:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-2-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-2-privatewith-header (192.168.60.196:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-3-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-3-public (192.168.30.226:8080)
  ❌ echo-ingress-l7/pod-to-pod-with-endpoints/curl-ipv4-3-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-3-privatewith-header (192.168.30.226:8080)
Test [echo-ingress-l7-named-port]:
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-2-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-2-public (192.168.60.196:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-2-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-2-privatewith-header (192.168.60.196:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-3-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-3-public (192.168.30.226:8080)
  ❌ echo-ingress-l7-named-port/pod-to-pod-with-endpoints/curl-ipv4-3-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-3-privatewith-header (192.168.30.226:8080)
Test [client-egress-l7-method]:
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-public (192.168.30.226:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-private: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-private (192.168.30.226:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-privatewith-header (192.168.30.226:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-public: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-public (192.168.60.196:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-private: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-private (192.168.60.196:8080)
  ❌ client-egress-l7-method/pod-to-pod-with-endpoints/curl-ipv4-1-privatewith-header: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> curl-ipv4-1-privatewith-header (192.168.60.196:8080)
Test [client-egress-l7]:
  ❌ client-egress-l7/pod-to-pod/curl-ipv4-2: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> cilium-test/echo-other-node-66bdd89578-tngkj (192.168.60.196:8080)
  ❌ client-egress-l7/pod-to-pod/curl-ipv4-3: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> cilium-test/echo-same-node-55db76dd44-bl58x (192.168.30.226:8080)
  ❌ client-egress-l7/pod-to-world/http-to-one.one.one.one-1: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> one.one.one.one-http (one.one.one.one:80)
Test [client-egress-l7-named-port]:
  ❌ client-egress-l7-named-port/pod-to-pod/curl-ipv4-2: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> cilium-test/echo-same-node-55db76dd44-bl58x (192.168.30.226:8080)
  ❌ client-egress-l7-named-port/pod-to-pod/curl-ipv4-3: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> cilium-test/echo-other-node-66bdd89578-tngkj (192.168.60.196:8080)
  ❌ client-egress-l7-named-port/pod-to-world/http-to-one.one.one.one-0: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> one.one.one.one-http (one.one.one.one:80)
Test [to-fqdns]:
  ❌ to-fqdns/pod-to-world/http-to-one.one.one.one-0: cilium-test/client-6965d549d5-spvkn (192.168.31.107) -> one.one.one.one-http (one.one.one.one:80)
  ❌ to-fqdns/pod-to-world/http-to-one.one.one.one-1: cilium-test/client2-76f4d7c5bc-pzsh2 (192.168.23.111) -> one.one.one.one-http (one.one.one.one:80)
connectivity test failed: 9 tests failed
```
