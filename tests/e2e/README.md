## E2E tests

Automated E2E tests for iter8-kfserving are work-in-progress.

For now, you can use [Fortio](https://github.com/fortio/fortio) to verify zero-downtime rollouts. Follow [quick start instructions](../../README.md), but replace Step 5 as follows:

```shell
GOBIN=/usr/local/bin go get fortio.org/fortio
fortio load -qps 2 -t 5m -H Host:${SERVICE_HOSTNAME} -payload-file samples/quickstart/input.json http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/${MODEL_NAME}:predict
```

The above command generates load for the InferenceService at a rate of 2 requests per second over a period of five minutes. You can `ctrl-c` out of this command as soon as the experiment completes. When you do so, you should see output similar to the following.

```shell
http://${INGRESS_HOST}:${INGRESS_PORT}/v1/models/${MODEL_NAME}:predict
Fortio 1.11.5-pre running at 2 queries per second, 12->12 procs, for 5m0s: http://127.0.0.1:80/v1/models/my-model:predict
22:11:15 I httprunner.go:81> Starting http test for http://127.0.0.1:80/v1/models/my-model:predict with 4 threads at 2.0 qps
Starting at 2 qps with 4 thread(s) [gomax 12] for 5m0s : 150 calls each (total 600)
^C22:15:19 I periodic.go:558> T002 ended after 4m2.943900419s : 121 calls. qps=0.4980573695874396
22:15:19 I periodic.go:558> T000 ended after 4m2.943885637s : 121 calls. qps=0.4980573998919028
22:15:19 I periodic.go:558> T003 ended after 4m2.943891634s : 121 calls. qps=0.49805738759749923
22:15:19 I periodic.go:558> T001 ended after 4m2.943911335s : 121 calls. qps=0.4980573472086353
Ended after 4m2.943990782s : 484 calls. qps=1.9922
Sleep times : count 484 avg 1.1804444 +/- 0.284 min 0.324798595 max 1.82301008 sum 571.335086
Aggregated Function Time : count 484 avg 0.83033911 +/- 0.2841 min 0.187650462 max 1.686257916 sum 401.884129
# range, mid point, percentile, count
>= 0.18765 <= 0.2 , 0.193825 , 0.83, 4
> 0.2 <= 0.25 , 0.225 , 5.17, 21
> 0.25 <= 0.3 , 0.275 , 8.26, 15
> 0.3 <= 0.35 , 0.325 , 9.50, 6
> 0.35 <= 0.4 , 0.375 , 9.71, 1
> 0.4 <= 0.45 , 0.425 , 9.92, 1
> 0.45 <= 0.5 , 0.475 , 15.08, 25
> 0.5 <= 0.6 , 0.55 , 21.28, 30
> 0.6 <= 0.7 , 0.65 , 25.21, 19
> 0.7 <= 0.8 , 0.75 , 40.08, 72
> 0.8 <= 0.9 , 0.85 , 51.86, 57
> 0.9 <= 1 , 0.95 , 67.98, 78
> 1 <= 1.68626 , 1.34313 , 100.00, 155
# target 50% 0.884211
# target 75% 1.15053
# target 90% 1.47197
# target 99% 1.66483
# target 99.9% 1.68412
Sockets used: 4 (for perfect keepalive, would be 4)
Jitter: false
Code 200 : 484 (100.0 %)
Response Header Sizes : count 484 avg 166.30579 +/- 0.4607 min 166 max 167 sum 80492
Response Body/Total Sizes : count 484 avg 388.30579 +/- 0.4607 min 388 max 389 sum 187940
All done 484 calls (plus 4 warmup) 830.339 ms avg, 2.0 qps
```

The fourth line from the end which says `Code 200: ... (100.0 %)` confirms that no requests were lost during the canary rollout.

