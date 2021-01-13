# Defining a Custom Metric

> Define custom iter8 metrics using Prometheus metrics and use them in iter8 experiments.

We illustrate custom metric creation using three examples. The first two examples illustrate `counter` metrics while the third illustrates `gauge` metrics.

### Example 1: Defining an iter8 counter metric named `correct-predictions`
Suppose you have a Prometheus counter metric named `correct_predictions`, which records the number of correct predictions made by each model version until now.
```shell
# Prometheus query to get the number of correct predictions for a model version in the past 30 seconds.
sum(increase(correct_predictions{revision_name='my-model-predictor-default-dlgm8'}[30s]))
```
```shell
# Prometheus query to get the number of correct predictions for another model version in the past 30 seconds.
sum(increase(correct_predictions{revision_name='my-model-predictor-default-h4bvl'}[30s]))
```
> **Note:** KFServing creates distinct Knative revisions for different model versions. Hence, as seen in the above examples, the `revision_name` label provides a convenient way to filter and select a specific model version.

You can turn this into an iter8 counter metric using the following yaml manifest.
```yaml
#correctpredictions.yaml
apiVersion: iter8.tools/v2alpha1
kind: Metric
metadata:
  name: correct-predictions
spec:
  params:
    query: sum(increase(correct_predictions{revision_name='$revision'}[$interval])) or on() vector(0)
  description: Number of correct predictions
  type: counter
  provider: prometheus
```
> **Note:** values may be unavailable for a metric in Prometheus, in which case, Prometheus may return a `nodata` response. For example, values may be unavailable for the `correct_predictions` metric for a model version if no requests have been sent to that model version until now, or if Prometheus has a large scrape interval and is yet to collect data. In such cases, the `on() or vector(0)` clause replaces the `nodata` response with a zero value. This is the recommended approach for creating iter8 counter metrics.


Using the yaml file defined above, you can create an iter8 metric in your Kubernetes cluster as follows.
```shell
kubectl apply -f correctpredictions.yaml -n your-metrics-namespace
```

You can now list this metric using `kubectl` and [use this metric in experiments](usingmetrics.md).
```shell
kubectl get metrics.iter8.tools correct-predictions -n your-metrics-namespace
NAMESPACE      NAME                           TYPE      DESCRIPTION
iter8-system   correct-predictions            counter   Number of correct predictions
```

### Instantiation of templated HTTP query params
Iter8 instantiates the templated HTTP query params (`spec.params`) before querying Prometheus in each iteration of the experiment. While instantiating the templated params, iter8 will substitute:

1. The template variable `$name` with the values `default` or `canary` for the two model versions in a canary experiment.
2. The template variable `$revision` with the revision name corresponding to the model versions.
3. The template variable `$interval` with the time elapsed since the start of the experiment (e.g., `80s` or `200s`).

<details>
More concretely, the following Python (pseudo) code snippet provides an approximate behind-the-scenes view of how iter8 instantiates the templated parameters and queries the metrics database.
<pre>
# Python (pseudo) code snippet intended to illustrate 'roughly' how iter8 queries a metrics database.
metrics_database_url = "https://prometheus-operated.kfserving-monitoring:9090/api/v1/query"
instantiated_params = substitute_template_variables(spec.params)
# Here is how instantiated_params might look at this point.
# instantiated_params = {'query': 'sum(increase(correct_predictions{revision_name='my-model-predictor-default-dlgm8'}[183s])) or on() vector(0)'}
# Using requests library API for HTTP GET
result = requests.get(metrics_database_url, params = instantiated_params).json()
</pre>
</details>

### Example 2: `request-count` metric
The `request-count` metric is an [out-of-the-box iter8 metric](../install/iter8-monitoring/metrics/revision-metrics.yaml). Although not a custom metric, this example serves to further illustrate the concepts introduced in Example 1. There is no real difference between custom and out-of-the-box metrics other than the fact the latter is shipped as part of iter8-kfserving.
```yaml
apiVersion: iter8.tools/v2alpha1
kind: Metric
metadata:
  name: request-count
spec:
  params:
    query: sum(increase(revision_app_request_latencies_count{revision_name='$revision'}[$interval])) or on() vector(0)
  description: Number of requests
  type: counter
  provider: prometheus
```

### Example 3: defining an iter8 gauge metric named `accuracy`
We will build on Examples 1 and 2 to define a new iter8 gauge metric called `accuracy`. This metric is intended to capture the ratio of correct predictions over request count.
```yaml
#accuracy.yaml
apiVersion: iter8.tools/v2alpha1
kind: Metric
metadata:
  name: accuracy
spec:
  description: Accuracy of the model version
  params:
    query: (sum(increase(correct_predictions{revision_name='$revision'}[$interval])) or on() vector(0)) / (sum(increase(revision_app_request_latencies_count{revision_name='$revision'}[$interval])) or on() vector(0))
  type: gauge
  sample_size: 
    name: request-count
  provider: prometheus
  ```

The `spec.sample_size` field represents the number of data points over which the gauge metric value is computed. In this case, since `accuracy` is computed over all the requests received by a specific model version, the sample_size metric is `request-count`.

## Prometheus response
The following is a sample response returned by Prometheus to iter8 for a metric query.
```json
{
    "status": "success",
    "data": {
      "resultType": "vector",
      "result": [
        {
          "value": [1556823494.744, "21.7639"]
        }
      ]
    }
}
```
There are typically two versions (`default` and `canary`) that are involved in an iter8-kfserving experiment. When iter8 queries Prometheus for a specific iter8-metric at any point in time, it issues two queries, one for each model version. For each query, iter8 expects the schema of the Prometheus response to match the schema of the above sample. Specifically, `status` should equal `success`, `resultType` should equal `vector` (i.e., Prometheus should return an instant-vector), with a single `result` within it.

