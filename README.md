Rancher Admission Mutating Webhook
====

Purpose of this webhook is to associate Aqua segmentation policy based off Rancher project id labels assigned to namespace.<br/>
Webhook will intercept k8s deployments and retrieve Rancher ProjectId from namespace field.cattle.io/projectId= and assign<br/>
to pod template.<br/><br/>
STATUS: experimental

## Configuration
In deploy/setup.sh<br/></br>
LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=field.cattle.io/projectId   #label key to insert into deployments<br/>
NAMESPACE=default     # namespace to deploy webhook, SA, ClusterRole, ClusterRoleBinding, etc
IMAGE_NAME=imagename/addlabel:latest  #webhook image name

## Installation
1. ./deploy/setup.sh 


