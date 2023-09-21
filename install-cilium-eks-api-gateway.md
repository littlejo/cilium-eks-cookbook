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
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

* This CRD depends on the version of cilium (version tested: 1.13)

```
aws eks describe-cluster --name basic-cilium | jq -r .cluster.endpoint
https://29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
API_SERVER_IP=29F17965D68DB5502F627B2D22596152.gr7.us-east-1.eks.amazonaws.com
API_SERVER_PORT=443

cilium install --version 1.14.2 \
               --set kubeProxyReplacement=true \
               --set gatewayAPI.enabled=true \
               --set eni.enabled=true \
               --set ipam.mode=eni \
               --set egressMasqueradeInterfaces=eth0 \
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

Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet              cilium             Desired: 2, Ready: 2/2, Available: 2/2
Containers:            cilium             Running: 2
                       cilium-operator    Running: 1
Cluster Pods:          2/2 managed by Cilium
Helm chart version:    1.14.2
Image versions         cilium             quay.io/cilium/cilium:v1.14.2@sha256:6263f3a3d5d63b267b538298dbeb5ae87da3efacf09a2c620446c873ba807d35: 2
                       cilium-operator    quay.io/cilium/operator-aws:v1.14.2@sha256:8d514a9eaa06b7a704d1ccead8c7e663334975e6584a815efe2b8c15244493f1: 1
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
GATEWAY=$(kubectl get gateway my-gateway -o jsonpath='{.status.addresses[0].value}')
curl --fail -s http://"$GATEWAY"/details/1 | jq
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
More information: https://github.com/cilium/cilium/issues/25357

# Test

> cilium connectivity test
