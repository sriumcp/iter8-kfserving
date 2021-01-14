## Describe experiments using iter8ctl

**[Iter8ctl](https://github.com/iter8-tools/iter8ctl)** is iter8's command line utility for service operators to understand and diagnose their iter8 experiments. Iter8ctl can be used with iter8-kfserving experiments.

### Installation
```
GOBIN=/usr/local/bin go get github.com/iter8-tools/iter8ctl@v0.1.0-alpha
```
The above command installs iter8ctl under the `/usr/local/bin` directory. To install under a different directory, change the value of `GOBIN` above.

# Usage

## Example 1
Describe an iter8 experiment resource object present in your Kubernetes cluster.
```shell
kubectl get experiment sklearn-iris-experiment-1 -n kfserving-test -o yaml > experiment.yaml
iter8ctl describe -f experiment.yaml
```

## Example 2
Supply experiment YAML using console input.
```shell
kubectl get experiment sklearn-iris-experiment-1 -n kfserving-test -o yaml > experiment.yaml
cat experiment.yaml | iter8ctl describe -f -
```

## Example 3
Periodically fetch an iter8 experiment resource object present in your Kubernetes cluster and describe it. You can change the frequency by adjusting the sleep interval below.
```shell
while clear; do
    kubectl get experiment sklearn-iris-experiment-1 -n kfserving-test -o yaml | iter8ctl describe -f -
    sleep 10.0
done
```

# Sample Output
The following sample output produced by iter8ctl is from the experiment used in [quick start instructions](https://github.com/iter8-tools/iter8-kfserving#quick-start-on-minikube).

```
******
Experiment name: experiment-1
Experiment namespace: default
Experiment target: default/my-model

******
Number of completed iterations: 10

******
Winning version: canary

******
Objectives
+--------------------------+---------+--------+
|        OBJECTIVE         | DEFAULT | CANARY |
+--------------------------+---------+--------+
| mean-latency <= 1000.000 | true    | true   |
+--------------------------+---------+--------+
| error-rate <= 0.010      | true    | true   |
+--------------------------+---------+--------+

******
Metrics
+--------------------------------+---------+---------+
|             METRIC             | DEFAULT | CANARY  |
+--------------------------------+---------+---------+
| request-count                  | 132.294 |  73.254 |
+--------------------------------+---------+---------+
| 95th-percentile-tail-latency   | 298.582 | 294.597 |
| (milliseconds)                 |         |         |
+--------------------------------+---------+---------+
| mean-latency (milliseconds)    | 229.529 | 230.090 |
+--------------------------------+---------+---------+
| error-rate                     |   0.000 |   0.000 |
+--------------------------------+---------+---------+
```

## Removing iter8ctl
```
rm <path-to-install-directory>/iter8ctl
```