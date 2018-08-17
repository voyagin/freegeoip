# VGEOIP Service for Voyagin

This service is based on the original [Apilayer's Freegeoip project](https://github.com/apilayer/freegeoip), with a little modifications.

## Kubernetes-style

It's advised that we use at minimum G1 machine type. We have tried using F1 before, but the machine became very unstable with a lot of restarts and crashes, and general unavailability. It's known that both F1 and G1 are shared vCPU, and that F1 shares 20% of the whole CPU whereby G1 is 60% of the total CPU usage.

### Deploying to a new cluster

Build the docker:

```
$ docker build -t gcr.io/voyagin-prod/vgeoip:1.0.0 .
```

Note: please increment the version/tag in someway. Also, we may change `voyagin-prod` with other project ID if necessary. The project ID can easily be located in the Google Console dashboard of said project.

Push to GCR (Google Container Registry):

```
$ gcloud docker -- push gcr.io/voyagin-prod/vgeoip:1.0.0
```

Create deployment:

```
$ kubectl create -f ./k8s/deployment.yml
```

Create service to expose to the internet:

```
$ kubectl create -f ./k8s/service.yml
```

### Migrating to another node pool

In the future we may want to upgrade our machine type to a higher one, or maybe even downgrading it. Before doing that however, we should try to have more nodes instead rather than to scale it vertically. Since this app does not require extensive computation, scaling it horizontally may be all that we need.

Nevertheless, let's see how we can migrate from one machine type to another machine type.

First, we can check what kind of pools we have:

```
$ gcloud container node-pools list --cluster cluster-vgeoip --region asia-northeast1
NAME     MACHINE_TYPE  DISK_SIZE_GB  NODE_VERSION
g1-pool  g1-small      50            1.9.7-gke.5
```

Then, prepare a new node pool. We can do that [through a beautiful UI](https://console.cloud.google.com/kubernetes/clusters/details/asia-northeast1/cluster-vgeoip):

1. Open the cluster page
2. Click Edit
3. Click Add node pool
4. Configure what kind of node pool we would like to have
4. Save

The next step, we will configure it through the command line. For the sake of completeness, we can also use the following command line tool to spawn a new node pool:

```
$ gcloud container node-pools create some-new-pool --cluster=cluster-vgeoip \
  --machine-type=n1-highmem-2 --num-nodes=3
```

The following command will then list all the pools that the cluster has:

```
$ kubectl get nodes
NAME                                             STATUS    ROLES     AGE       VERSION
gke-cluster-vgeoip-g1-pool-0819df37-1lhd         Ready     <none>    22h       v1.9.7-gke.5
gke-cluster-vgeoip-g1-pool-4faa1bb5-4psb         Ready     <none>    22h       v1.9.7-gke.5
gke-cluster-vgeoip-g1-pool-689dc04a-hsb0         Ready     <none>    22h       v1.9.7-gke.5
gke-cluster-vgeoip-some-new-pool-ab19gh37-1mnd   Ready     <none>    5s        v1.9.7-gke.5
gke-cluster-vgeoip-some-new-pool-cdaaijb5-4pop   Ready     <none>    8s        v1.9.7-gke.5
gke-cluster-vgeoip-some-new-pool-ef9djk4a-hsrs   Ready     <none>    5s        v1.9.7-gke.5
```

Cool! Next, we need to _cordon_ the old pools. Cordoning pool make it _unschedulable_, so this node won't accommodate a pod anymore. After we cordon it, we will evicts the workloads on the original, old node pool to the new one in a graceful manner.

To cordon it:

```
$ for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=g1-pool -o=name); do
  kubectl cordon "$node";
done
```

Replace `g1-pool` above with the pool name of which we want to cordon.

If we run `kubectl get nodes` we would see nodes of `g1-pool` having a `SchedulingDisabled` status.

And then, now we can drain it (also change `g1-pool` appropriately):


```
$ for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=g1-pool -o=name); do
  kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 "$node";
done
```

Now we can delete the old pool:

```
$ gcloud container node-pools delete g1-pool --cluster cluster-vgeoip --region asia-northeast1
```

Done. In case there are issues with steps above (perhaps the CLI no longer support some command), please feel free to refer to the [original documentation](https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool).

### Enabling logging to Stackdriver

This should be done only once, for eg. when creating a new cluster, or perhaps after migrating to a new cluster.

First of all, ensure the the [Stackdriver Logging API is enabled](https://console.developers.google.com/apis/library/logging.googleapis.com?project=voyagin-prod).

```
$ kubectl apply -f ./k8s/configmap-fluentd.yml
$ kubectl apply -f ./k8s/daemonset-fluentd.yml
```

To check if they are running with all their might:

```
$ kubectl get pods --namespace=kube-system

fluentd-gcp-v2.0-dzrcd             2/2       Running   0          39s
fluentd-gcp-v2.0.17-844ss          2/2       Running   0          1h
fluentd-gcp-v2.0.17-mf5mt          2/2       Running   0          1h
fluentd-gcp-v2.0.17-xsqsm          2/2       Running   0          1h
```

To see the logs in GCP, visit Stackdriver Logging (you may need an access permission to be able to visit this page), and then at the "Logs" section, choose "GKE Container, cluster-vgeoip" and all the logs should be there.

![logs](https://user-images.githubusercontent.com/166730/44245140-45441180-a212-11e8-8912-9ec18005d004.png)

We can also see the log of individual pods:

```
$ kubectl get pods
NAME                         READY     STATUS    RESTARTS   AGE
vgeoip-app-9594657b8-b7r7z   1/1       Running   0          17m
vgeoip-app-9594657b8-dpvt6   1/1       Running   0          17m
vgeoip-app-9594657b8-ff6br   1/1       Running   0          17m
$ kubectl logs vgeoip-app-9594657b8-ff6br
2018/08/17 02:23:30 freegeoip http server starting on :8080
```

### Re-deploy

```
$ kubectl edit -f deployment.yml
```

### Misc

Get all pods in the cluster:

```
$ kubectl get pods
```

Which will return something like:

```
NAME                          READY     STATUS    RESTARTS   AGE
vgeoip-app-77c47d8894-2m7x9   0/1       Unknown   6          1h
vgeoip-app-77c47d8894-5qwf5   0/1       Pending   0          2m
vgeoip-app-77c47d8894-9zqrm   1/1       Unknown   5          29m
vgeoip-app-77c47d8894-j92wm   0/1       Pending   0          2m
```

We can get some logs from the pods:

```
$ kubectl logs vgeoip-app-77c47d8894-2m7x9
```
