Rancher Admission Mutating Webhook
====

Purpose of this webhook is to associate Aqua segmentation policy based off
Rancher projectId labels assigned to namespace.

The Webhook will intercept k8s deployments and retrieve Rancher ProjectId from
namespace field.cattle.io/projectId= and assign to pod template.

STATUS: development

## Configuration
In the file `deploy/setup.sh`

    LABEL_KEY_LOOKING_FOR_ON_NAMESPACE=field.cattle.io/projectId
    LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=field.cattle.io/projectId
    IMAGE_NAME=imagename/addlabel:latest  #webhook image name.

assumes `--enable-admission-plugins=MutatingAdmissionWebhook` enabled on k8s api server.

https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers 

## Installation

Execute `./deploy/setup.sh`

## Tests

To run tests: `python -m unittest test/test_request.py`

Assumes >= Python 3.7.4

## Overview
![alt tag](webhook_overview.png?raw=true "overview")<!-- .element height="50%" width="50%" -->


