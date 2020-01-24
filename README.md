Rancher Admission Mutating Webhook
====

Purpose of this webhook is to associate Aqua segmentation policy based off
Rancher projectId labels assigned to namespace.

The Webhook will intercept CREATE and UPDATE operations on k8s pods and
retrieve Rancher ProjectId from the parent namepace's
`field.cattle.io/projectId=` label, and assign it as a Pod label.

STATUS: development

## Configuration

Look at the top of the file `deploy/setup.sh` for a number of environment
variables that configure behavior

Functionality assumes `--enable-admission-plugins=MutatingAdmissionWebhook` enabled on k8s api server.

https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers 

## Installation

Execute `./deploy/setup.sh`

## Tests

To run tests: `python -m unittest test/test_request.py`

Assumes >= Python 3.7.4

## Troubleshooting

The `add-labels-*` pods will emit terse but useful information to STDOUT, e.g.:

    Processing CREATE operation on Pod/v1 named webapp-778bb599cd-?? in pkrizaktest namespace
    Found label {'field.cattle.io/projectId': 'p-8v8fr'} on namespace pkrizaktest
    Applied label drekar.qualcomm.com~1projectId=p-8v8fr to pod
    172.19.5.0 - - [24/Jan/2020 01:04:53] "POST /addlabel?timeout=30s HTTP/1.1" 200 -

    Processing UPDATE operation on Pod/v1 named webapp-778bb599cd-5gwn6 in pkrizaktest namespace
    Found label {'field.cattle.io/projectId': 'p-8v8fr'} on namespace pkrizaktest
    Applied label drekar.qualcomm.com~1projectId=p-8v8fr to pod
    172.19.5.0 - - [24/Jan/2020 01:05:20] "POST /addlabel?timeout=30s HTTP/1.1" 200 -

For more verbose information, edit the `add-labels` deployment and set
`WEBHOOK_DEBUG` environment variable to `"1"`.  In addition to the
terse information shown above, the contents of the admission request
will be logged.  This is very helpful when troubleshooting a `KeyError`
in the code or something.

If the admission controller doesn't seem to be executing at all,
examine the logs of the kube-apiserver.  For example, this is
an error message indicating that the SSL certificate has the
wrong CN (it needs to match the K8s service name).

    1 dispatcher.go:137] failed calling webhook "addlabel.aquasec.com": Post https://addlabel-webhook.aqua-addlabel-webhook.svc:443/addlabel?timeox509: certificate is valid for addlabel-webhook.default.svc, not addlabel-webhook.aqua-addlabel-webhook.svc

## Overview
![alt tag](webhook_overview.png?raw=true "overview")<!-- .element height="50%" width="50%" -->


