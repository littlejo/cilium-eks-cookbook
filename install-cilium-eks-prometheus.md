# Use case

* Install prometheus to outsource metrics from cilium and hubble

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)
* [helm](tools/helm.txt)

# Cluster installation

exactly the same as [install-cilium-eks.md](install-cilium-eks.md)

# Cilium installation

> kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'

installation of cilium with prometheus metrics activated:

```
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system \
                                  --set eni.enabled=true \
                                  --set ipam.mode=eni \
                                  --set egressMasqueradeInterfaces=eth0 \
                                  --set tunnel=disabled \
                                  --set prometheus.enabled=true \
                                  --set operator.prometheus.enabled=true
```

Check

```
kubectl get pod -n kube-system --selector k8s-app=cilium -o json | jq '.items[0].metadata.annotations'
{
  "container.apparmor.security.beta.kubernetes.io/apply-sysctl-overwrites": "unconfined",
  "container.apparmor.security.beta.kubernetes.io/cilium-agent": "unconfined",
  "container.apparmor.security.beta.kubernetes.io/clean-cilium-state": "unconfined",
  "container.apparmor.security.beta.kubernetes.io/mount-cgroup": "unconfined",
  "prometheus.io/port": "9962",
  "prometheus.io/scrape": "true"
}
```

# Hubble

To use metrics from hubble:

```
helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values --set hubble.enabled=true --set hubble.metrics.enabled="{dns,drop:sourceContext=pod;destinationContext=pod,tcp,flow,port-distribution,httpV2}"
kubectl rollout restart daemonset/cilium -n kube-system
```

# Prometheus and Grafana

To install prometheus and to see this metrics on grafana:

```
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/kubernetes/addons/prometheus/monitoring-example.yaml
kubectl -n cilium-monitoring port-forward service/grafana --address 0.0.0.0 --address :: 3000:3000
```

You can connect to this url to see grafana and cilium metrics: http://localhost:3000

# Example of test

If you have no idea what to test, example:

```
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/minikube/http-sw-app.yaml
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/minikube/sw_l3_l4_l7_policy.yaml
```
