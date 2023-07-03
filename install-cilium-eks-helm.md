# Use case

* Install cilium using helm on eks cluster.
* eni mode

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)
* [helm](tools/helm.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md#cluster-installation)

# Cilium installation

> kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
```
helm install cilium cilium/cilium --version 1.13.4 \
  --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth0 \
  --set tunnel=disabled
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

```
kubectl exec -n kube-system ds/cilium -- cilium status --verbose
Defaulted container "cilium-agent" out of: cilium-agent, config (init), mount-cgroup (init), apply-sysctl-overwrites (init), mount-bpf-fs (init), clean-cilium-state (init), install-cni-binaries (init)
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.27+ (v1.27.3-eks-a5565ad) [linux/amd64]
Kubernetes APIs:        ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Disabled
Host firewall:          Disabled
CNI Chaining:           none
CNI Config file:        CNI configuration file management disabled
Cilium:                 Ok   1.13.4 (v1.13.4-4061cdfc)
NodeMonitor:            Listening for events on 2 CPUs with 64x4096 of shared memory
Cilium health daemon:   Ok
IPAM:                   IPv4: 4/12 allocated,
Allocated addresses:
  192.168.18.93 (kube-system/coredns-79df7fff65-md6hc)
  192.168.28.58 (router)
  192.168.30.127 (kube-system/coredns-79df7fff65-2x4sj)
  192.168.9.25 (health)
IPv6 BIG TCP:           Disabled
BandwidthManager:       Disabled
Host Routing:           Legacy
Masquerading:           IPTables [IPv4: Enabled, IPv6: Disabled]
Clock Source for BPF:   jiffies   [250 Hz]
Controller Status:      26/26 healthy
  Name                                  Last success   Last error   Count   Message
  cilium-health-ep                      1m3s ago       never        0       no error
  dns-garbage-collector-job             12s ago        never        0       no error
  endpoint-200-regeneration-recovery    never          never        0       no error
  endpoint-2986-regeneration-recovery   never          never        0       no error
  endpoint-34-regeneration-recovery     never          never        0       no error
  endpoint-3867-regeneration-recovery   never          never        0       no error
  endpoint-gc                           3m12s ago      never        0       no error
  ipcache-inject-labels                 3m1s ago       3m5s ago     0       no error
  k8s-heartbeat                         12s ago        never        0       no error
  link-cache                            19s ago        never        0       no error
  metricsmap-bpf-prom-sync              7s ago         never        0       no error
  resolve-identity-200                  3m4s ago       never        0       no error
  resolve-identity-2986                 3m3s ago       never        0       no error
  resolve-identity-34                   3m2s ago       never        0       no error
  resolve-identity-3867                 3m2s ago       never        0       no error
  sync-endpoints-and-host-ips           4s ago         never        0       no error
  sync-lb-maps-with-k8s-services        3m4s ago       never        0       no error
  sync-policymap-200                    1m0s ago       never        0       no error
  sync-policymap-2986                   1m0s ago       never        0       no error
  sync-policymap-34                     1m0s ago       never        0       no error
  sync-policymap-3867                   1m0s ago       never        0       no error
  sync-to-k8s-ciliumendpoint (200)      4s ago         never        0       no error
  sync-to-k8s-ciliumendpoint (2986)     13s ago        never        0       no error
  sync-to-k8s-ciliumendpoint (34)       12s ago        never        0       no error
  sync-to-k8s-ciliumendpoint (3867)     12s ago        never        0       no error
  template-dir-watcher                  never          never        0       no error
Proxy Status:            OK, ip 192.168.28.58, 0 redirects active on ports 10000-20000
Global Identity Range:   min 256, max 65535
Hubble:                  Ok   Current/Max Flows: 607/4095 (14.82%), Flows/s: 3.05   Metrics: Disabled
KubeProxyReplacement Details:
  Status:                 Disabled
  Socket LB:              Disabled
  Socket LB Tracing:      Disabled
  Socket LB Coverage:     Full
  Session Affinity:       Disabled
  Graceful Termination:   Enabled
  NAT46/64 Support:       Disabled
  Services:
  - ClusterIP:      Enabled
  - NodePort:       Disabled
  - LoadBalancer:   Disabled
  - externalIPs:    Disabled
  - HostPort:       Disabled
BPF Maps:   dynamic sizing: on (ratio: 0.002500)
  Name                          Size
  Non-TCP connection tracking   65536
  TCP connection tracking       131072
  Endpoint policy               65535
  Events                        2
  IP cache                      512000
  IP masquerading agent         16384
  IPv4 fragmentation            8192
  IPv4 service                  65536
  IPv6 service                  65536
  IPv4 service backend          65536
  IPv6 service backend          65536
  IPv4 service reverse NAT      65536
  IPv6 service reverse NAT      65536
  Metrics                       1024
  NAT                           131072
  Neighbor table                131072
  Global policy                 16384
  Per endpoint policy           65536
  Session affinity              65536
  Signal                        2
  Sockmap                       65535
  Sock reverse NAT              65536
  Tunnel                        65536
Encryption:                                    Disabled
Cluster health:                                2/2 reachable    (2023-07-03T11:01:07Z)
  Name                                         IP               Node        Endpoints
  ip-192-168-18-119.ec2.internal (localhost)   192.168.18.119   reachable   reachable
  ip-192-168-43-133.ec2.internal               192.168.43.133   reachable   reachable
```

# Test

> cilium connectivity test
