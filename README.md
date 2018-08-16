# VGEOIP Service for Voyagin

This service is based on the original [Apilayer's Freegeoip project](https://github.com/apilayer/freegeoip), with a little modifications.

## Kubernetes-style

It's advised that we use at minimum G1 machine type. We have tried using F1 before, but the machine became very unstable with a lot of restarts and crashes, and general unavailability. It's known that both F1 and G1 are shared vCPU, and that F1 shares 20% of the whole CPU whereby G1 is 60% of the total CPU usage.

### Deploying to a new cluster

Build the docker:

```
$ docker build -t gcr.io/{project-id}/vgeoip:1.0.0 .
```

Push to GCR (Google Container Registry):

```
$ gcloud docker -- push gcr.io/{project-id}/vgeoip:1.0.0
```

Create deployment:

```
$ kubectl create -f deployment.yml
```

Create service to expose to the internet:

```
$ kubectl create -f service.yml
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
