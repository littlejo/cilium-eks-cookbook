# Use case

* Install cilium and api gateway on eks clusters

# Requirements

* [eksctl (tested version: 0.143.0)](tools/eksctl.txt)
* [kubectl](tools/kubectl.txt)
* [cilium cli](tools/cilium-cli.txt)
* [aws-iam-authenticator](tools/aws-iam-authenticator.txt)
* [helm](tools/helm.txt)

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

* Install CRD:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.5.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.5.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.5.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.5.1/config/crd/experimental/gateway.networking.k8s.io_referencegrants.yaml
```

* This CRD depends on the version of cilium (version tested: 1.13)

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
                                  --set gatewayAPI.enabled=true \
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


## Check

```
cilium config view | grep "enable-gateway-api"
enable-gateway-api                             true
enable-gateway-api-secrets-sync                true
```

```
kubectl get gatewayclasses.gateway.networking.k8s.io
NAME     CONTROLLER                     ACCEPTED   AGE
cilium   io.cilium/gateway-controller   True       115s
```

* Install a webapps test:
> kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.12/samples/bookinfo/platform/kube/bookinfo.yaml

* Install Gateway and http route
> kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.13.0/examples/kubernetes/gateway/basic-http.yaml

* Get the url:

```
kubectl get svc cilium-gateway-my-gateway
NAME                        TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
cilium-gateway-my-gateway   LoadBalancer   10.100.228.21   abe9a5b2820814677afd5b280b49909f-827090963.us-east-1.elb.amazonaws.com   80:31921/TCP   63s
kubectl get gateway
NAME         CLASS    ADDRESS                                                                  READY   AGE
my-gateway   cilium   abe9a5b2820814677afd5b280b49909f-827090963.us-east-1.elb.amazonaws.com   True    2m49s
```

* It works:
```
curl --fail -s http://abe9a5b2820814677afd5b280b49909f-827090963.us-east-1.elb.amazonaws.com/details/1 | jq
{
  "id": 1,
  "author": "William Shakespeare",
  "year": 1595,
  "type": "paperback",
  "pages": 200,
  "publisher": "PublisherA",
  "language": "English",
  "ISBN-10": "1234567890",
  "ISBN-13": "123-1234567890"
}
```

If you see on AWS Console or in aws cli:
```
aws elbv2 describe-load-balancers
{
    "LoadBalancers": []
}
aws elb describe-load-balancers | jq .LoadBalancerDescriptions[].DNSName
"abe9a5b2820814677afd5b280b49909f-827090963.us-east-1.elb.amazonaws.com"
```

By default it creates a classic load balancer which is deprecated. How to create an alb or a nlb and its options?

# Test

> cilium connectivity test
