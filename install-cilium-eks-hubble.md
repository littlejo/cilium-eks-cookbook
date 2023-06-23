# Use case

* Install cilium and hubble to observe the network
* ipam mode: eni

# Requirements

* eksctl (minimum version: 0.143.0)
* kubectl
* cilium cli
* aws-iam-authenticator
* hubble

# Cluster installation

exactly the same as install-cilium-eks.md

# Cilium installation

exactly the same as install-cilium-eks.md

# Hubble installation

https://docs.cilium.io/en/stable/gettingstarted/hubble_setup/

> cilium hubble enable

## Test

### Example

```
kubectl create ns cilium-test
kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/kubernetes/connectivity-check/connectivity-check.yaml

cilium hubble port-forward&
```

```
hubble status
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 429/8,190 (5.24%)
Flows/s: 6.14
Connected Nodes: 2/2
```

> hubble observe

## Hubble ui installation

```
cilium hubble disable
cilium hubble enable --ui
```
