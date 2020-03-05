#!/bin/bash
# vim: syntax=sh ts=4 sts=4 sw=4 expandtab

# Abort if any command exits non-zero
set -e

PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

### configuraton
IMAGE_NAME="docker-registry.qualcomm.com/drekar/aqua-addlabel:0.11"
MAINTAINER='Jeff Thorne'
EMAIL='jthorne@u.washington.edu'
LABEL_KEY_LOOKING_FOR_ON_NAMESPACE=field.cattle.io/projectId #the label key on the parent namespace that contains the project ID
LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=drekar.qualcomm.com/projectId #label key to tattoo into deployments
SERVICE_NAME=addlabel-webhook
NAMESPACE=aqua-addlabel-webhook
BUILD_DIR=/tmp/aqua-addlabel-deploy # should be on local disk, not NFS
DEBUG=0
K8S_DEPLOYMENT_TYPE=DaemonSet  #if changed to deployment add replicas to manifest
### end configuraton

# Ensure we have a $KUBECONFIG set
echo "Checking for KUBECONFIG..."
if [ -z "$KUBECONFIG" ] || [ ! -r "$KUBECONFIG" ]; then
    echo "ERROR: KUBECONFIG not set"
    exit 1
fi

# Ensure our namespace exists before proceeding
echo "Checking for $NAMESPACE namespace..."
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "ERROR: Namespace $NAMESPACE does not exist. Please create it in the System project to continue"
    exit 1
fi

# Ensure our build dir exists
echo "Creating $BUILD_DIR/{deploy,secrets}..."
mkdir -p $BUILD_DIR/deploy
mkdir -p $BUILD_DIR/certs

echo "Creating $BUILD_DIR/deploy/Dockerfile..."
cat <<EOF >$BUILD_DIR/deploy/Dockerfile
FROM python:3.8-alpine
MAINTAINER $MAINTAINER

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV FLASK_APP=/app/add_label.py
ENV FLASK_ENV=default

EXPOSE 443


WORKDIR /app
COPY app/requirements.txt /
RUN apk update && pip install -r /requirements.txt
COPY app /app

CMD python add_label.py

ENV LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=$LABEL_KEY_TO_ADD_TO_DEPLOYMENTS
ENV LABEL_KEY_LOOKING_FOR_ON_NAMESPACE=$LABEL_KEY_LOOKING_FOR_ON_NAMESPACE
ENV FLASK_DEBUG=$DEBUG
EOF

echo "Building $IMAGE_NAME..."
docker build -t $IMAGE_NAME --file $BUILD_DIR/deploy/Dockerfile .
echo "Pushing $IMAGE_NAME..."
docker push $IMAGE_NAME

echo "Creating certificates in $BUILD_DIR/certs..."
cp deploy/certs/generate_certs.sh $BUILD_DIR/certs/
docker run --rm -v $BUILD_DIR/certs:/certs jordi/openssl bash /certs/generate_certs.sh $SERVICE_NAME.$NAMESPACE.svc

echo "Creating $BUILD_DIR/deploy/cluster_role.yaml..."
cat <<EOF >$BUILD_DIR/deploy/cluster_role.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: addlabel-sa
  namespace: $NAMESPACE
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: aqua-addlabel-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aqua-addlabel-rolebinding
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aqua-addlabel-role
subjects:
- kind: ServiceAccount
  name: addlabel-sa
  namespace: $NAMESPACE
EOF

echo "Creating $BUILD_DIR/deploy/register_controller.yaml..."
cat <<EOF >$BUILD_DIR/deploy/register_controller.yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: addlabel-admission-hook-config
  labels:
    component: mutating-controller
webhooks:
  - name: addlabel.aquasec.com
    failurePolicy: Ignore
    clientConfig:
      service:
        name: addlabel-webhook
        namespace: $NAMESPACE
        path: /addlabel
      caBundle: $(cat $BUILD_DIR/certs/ca.crt | base64 | tr -d '\n') # a base64 encoded self signed ca cert is needed because all Admission Webhooks need to be on SSL
    rules:
      - apiGroups: ["*"]
        resources: ["pods"]
        apiVersions: ["*"]
        operations: ["CREATE", "UPDATE"]
EOF

echo "Creating $BUILD_DIR/deploy/deploy_controller.yaml..."
cat <<EOF >$BUILD_DIR/deploy/deploy_controller.yaml
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    app: add-labels
---
apiVersion: apps/v1 # for versions before 1.8.0 use apps/v1beta1
kind: $K8S_DEPLOYMENT_TYPE
metadata:
  name: add-labels
  namespace: $NAMESPACE
  labels:
    app: add-labels
spec:
  selector:
    matchLabels:
      app: add-labels
  template:
    metadata:
      labels:
        app: add-labels
    spec:
      serviceAccountName: addlabel-sa
      containers:
        - image: $IMAGE_NAME
          name: add-labels
          imagePullPolicy: Always
          livenessProbe:
            httpGet:
              path: /liveness
              port: 8443
              scheme: HTTPS
          tty: true
          ports:
            - containerPort: 8443
              name: app
          env:
            - name: TLS_SERVER_CERT_FILEPATH
              value: /certs/server.crt
            - name: TLS_SERVER_KEY_FILEPATH
              value: /certs/server.key
            - name: WEBHOOK_DEBUG
              value: "$DEBUG"
          volumeMounts:
            - name: "certs"
              mountPath: "/certs"
      volumes:
        - name: "certs"
          secret:
            secretName: "addlabel-certs"
EOF

echo "Cleaning up existing resources..."
kubectl delete secret addlabel-certs -n $NAMESPACE 2>/dev/null || true
kubectl delete -f $BUILD_DIR/deploy/cluster_role.yaml -n $NAMESPACE 2>/dev/null || true
kubectl delete -f $BUILD_DIR/deploy/deploy_controller.yaml -n $NAMESPACE 2>/dev/null || true
kubectl delete -f $BUILD_DIR/deploy/register_controller.yaml -n $NAMESPACE 2>/dev/null || true

echo "Creating secret addlabel-certs in $NAMESPACE namespace..."
kubectl create secret generic addlabel-certs --from-file $BUILD_DIR/certs/server.key --from-file $BUILD_DIR/certs/server.crt -n $NAMESPACE

echo "Creating service account and ClusterRole..."
kubectl create -f $BUILD_DIR/deploy/cluster_role.yaml

echo "Creating admission controller..."
kubectl create -f $BUILD_DIR/deploy/deploy_controller.yaml

echo "Registering admission controller..."
kubectl create -f $BUILD_DIR/deploy/register_controller.yaml

echo "Deployment complete."
echo "Resource manifests are in $BUILD_DIR/deploy"
echo "Certificates are in $BUILD_DIR/certs"
exit 0

