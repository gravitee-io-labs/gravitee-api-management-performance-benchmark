![Document header](./assets/images/readme-header.png)

# G.io API Management Performance Tests

Run performance tests for Gravitee.io API Management with [K6](https://github.com/grafana/k6), [Prometheus](https://github.com/prometheus/prometheus) and [Grafana](https://github.com/grafana/grafana) on Kubernetes.

## How we did it and our results

> [!NOTE]
> Comming soon

## Do the tests yourself

### Setup

To perform these tests yourself, you will need :
- A kubernetes cluster with at least 4 worker nodes. For local testing (not recommended, as it is biased and limited), you can use minikube, k3s or kind, for example.
- Kubectl ([installation guide](https://kubernetes.io/docs/tasks/tools/#kubectl))
- Helm ([installation guide](https://helm.sh/docs/intro/install/))

#### [Optional, not recommended] Create a local kubernetes cluster with kind

> [!WARNING]
> Using a local kubernetes cluster is not recommended, as it is biased and limited. Hardware resources will be shared between all components, and the network topology is not representative of a real deployment. However, for small-scale one-off tests, it may be sufficient to validate minimal requirements (a few hundred or even thousands of calls per second).

1. Install kind [following the officiel documentation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).

2. Create a kind cluster, with [labels on nodes](https://kind.sigs.k8s.io/docs/user/configuration/#extra-labels) to apply [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) ([example](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/#create-a-pod-that-gets-scheduled-to-your-chosen-node)).

Customise the cluster by providing the `gravitee-apim-perf-test-cluster.yaml` file :

https://github.com/gravitee-io-labs/gravitee-api-management-performance-benchmark/blob/80aeedb180b0d0d02b3533cf7a426eb9ad1d5ddf/kind/gravitee-apim-perf-test-cluster.yaml#L1-L27

```sh
kind create cluster --config kind/gravitee-apim-perf-test-cluster.yaml
```

Configure kubectl to use this cluster.
```sh
kubectl cluster-info --context kind-gravitee-apim-perf-test
```

List nodes with their labels
```sh
kubectl get nodes --show-labels
```

3. Install Nginx ingress controler, unless you prefer to [use Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

#### Install Gravitee.io API Management

To install Gravitee.io API Management on kubernetes we will use the helm chart.

1. Add and update the `graviteeio` helm repo

```sh
helm repo add graviteeio https://helm.gravitee.io && \
helm repo update graviteeio
```

2. Install the Gravitee.io API Management Gateway

Customise the installation by providong the `values.yaml` file :

https://github.com/gravitee-io-labs/gravitee-api-management-performance-benchmark/blob/80aeedb180b0d0d02b3533cf7a426eb9ad1d5ddf/gio-apim/values.yaml#L1-L31

```sh
helm install apim -f gio-apim/values.yaml graviteeio/apim --create-namespace --namespace gio-apim
```

Watch all containers come up

```sh
kubectl get pods --namespace=gio-apim -l app.kubernetes.io/instance=apim -o wide -w
```

#### Install Gravitee.io Kubenertes Operator (GKO)

We will also use the Gravitee.io Kubernetes Operator (GKO) to deploy the APIs used during the performance test.

1. Deploy the Gravitee.io Kubernetes Operator (GKO)

```sh
helm install gko graviteeio/gko --create-namespace --namespace gio-apim
```

#### K6 

1. Add and update the `grafana` helm repo

```sh
helm repo add grafana https://grafana.github.io/helm-charts && \
helm repo update grafana
```

2. Install k6 kubernetes operator

```sh
helm install k6-operator grafana/k6-operator
```

#### Prometheus

1. Add and update the `bitnami` helm repo

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami && \
helm repo update bitnami
```

2. Install Prometheus

Customise the installation by providong the `values.yaml` file :

https://github.com/gravitee-io-labs/gravitee-api-management-performance-benchmark/blob/80aeedb180b0d0d02b3533cf7a426eb9ad1d5ddf/prometheus/values.yaml#L1-L4

```sh
helm install prometheus -f prometheus/values.yaml bitnami/kube-prometheus --create-namespace --namespace prometheus
```

#### Grafana

1. Deploy Prometheus datasource and dashboard

```sh
kubectl create ns grafana && \
kubectl create secret generic datasource-secret --from-file=./grafana/datasource-secret.yaml -n grafana && \
kubectl create configmap k6-prometheus-dashboard --from-file=./grafana/k6-prometheus-dashboard.json -n grafana
```

2. Install Grafana

Customise the installation by providong the `values.yaml` file :

https://github.com/gravitee-io-labs/gravitee-api-management-performance-benchmark/blob/80aeedb180b0d0d02b3533cf7a426eb9ad1d5ddf/grafana/values.yaml#L1-L12

```sh
helm install grafana -f grafana/values.yaml bitnami/grafana --create-namespace --namespace grafana
```

### Execute load testings scenarios

1. Deploy the API

```sh
kubectl apply -f scenarios/0-passthrough/apim-echo-v1.yaml --namespace=gio-apim
```

2. Deploy test scripts and execute scenario

Create a dedicated namespace to execute the performance tests

```sh
kubectl create ns k6-perf-tests
```

Deploy the k6 test script to a configmap

```sh
kubectl create configmap 0-passthrough --from-file scenarios/0-passthrough/test.js -n k6-perf-tests
```

Deploy the k6 Test Run ressource, this will trigger the k6 operator and create a job running k6 runner(s).

```sh
kubectl apply -f scenarios/0-passthrough/k6-testrun.yaml -n k6-perf-tests
```

At the end of the load testings scenario delete both ressources.

```sh
kubectl delete configmap 0-passthrough -n k6-perf-tests && \
kubectl delete -f scenarios/0-passthrough/k6-testrun.yaml -n k6-perf-tests
```

### Uninstall

Just delete the used namespaces or the cluster itself.

If you used a local kubernetes with kind

```sh
kind delete cluster --name gravitee-apim-perf-test
```

> [!NOTE]
> If you don't remember the cluster name, you have it in the [kind cluster configuration file](./kind/gravitee-apim-perf-test-cluster.yaml), or find it with `kind get clusters`.
