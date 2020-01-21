### configuraton
IMAGE_NAME=jeffthorne/addlabel:latest   #this script will build and push an image with this name. Registry access assumed.
MAINTAINER='Jeff Thorne'
EMAIL='jthorne@u.washington.edu'
LABEL_KEY_LOOKING_FOR_ON_NAMESPACE=field.cattle.io/projectId
LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=field.cattle.io/projectId #label key to insert into deployments
### end configuraton

cat <<EOF >deploy/Dockerfile
FROM python:3.7-slim
MAINTAINER $MAINTAINER

ENV FLASK_APP=/app/add_label.py
ENV FLASK_DEBUG=1
ENV FLASK_ENV=default
ENV LABEL_KEY_TO_ADD_TO_DEPLOYMENTS=$LABEL_KEY_TO_ADD_TO_DEPLOYMENTS
ENV LABEL_KEY_LOOKING_FOR_ON_NAMESPACE=$LABEL_KEY_LOOKING_FOR_ON_NAMESPACE
WORKDIR /app
EXPOSE 443


RUN apt-get update

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY app/requirements.txt /
RUN pip install -r /requirements.txt
COPY app /app
CMD python add_label.py
EOF


docker build -t $IMAGE_NAME --file ./deploy/Dockerfile .
docker push $IMAGE_NAME

docker run --rm -v `pwd`/deploy/certs:/certs jordi/openssl bash /certs/generate_certs.sh

NAMESPACE=default

cat <<EOF >deploy/cluster_role.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: addlabel-sa
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: addlabel-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: addlabel-rolebinding
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: addlabel-role
subjects:
- kind: ServiceAccount
  name: addlabel-sa
  namespace: $NAMESPACE
EOF

cat <<EOF >deploy/register_controller.yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: addlabel-admission-hook-config
  namespace: $NAMESPACE
  labels:
    component: mutating-controller
webhooks:
  - name: addlabel.aquasec.com
    failurePolicy: Ignore
    clientConfig:
      service:
        name: addlabel-webhook
        namespace: $NAMESPACE
        path: /add/labels/deployments
      caBundle: $(cat deploy/certs/ca.crt | base64 | tr -d '\n') # a base64 encoded self signed ca cert is needed because all Admission Webhooks need to be on SSL
    rules:
      - apiGroups: ["*"]
        resources: ["deployments"]
        apiVersions: ["*"]
        operations: ["CREATE", "UPDATE"]
EOF


cat <<EOF >deploy/deploy_controller.yaml
apiVersion: v1
kind: Service
metadata:
  name: addlabel-webhook
  namespace: $NAMESPACE
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    app: add-labels
---
apiVersion: apps/v1 # for versions before 1.8.0 use apps/v1beta1
kind: Deployment
metadata:
  name: add-labels
  namespace: $NAMESPACE
  labels:
    app: add-labels
spec:
  replicas: 1
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
          volumeMounts:
            - name: "certs"
              mountPath: "/certs"
      volumes:
        - name: "certs"
          secret:
            secretName: "addlabel-certs"
EOF

kubectl create namespace $NAMESPACE
kubectl delete secret addlabel-certs -n $NAMESPACE
kubectl create secret generic addlabel-certs --from-file deploy/certs/server.key --from-file deploy/certs/server.crt -n $NAMESPACE


kubectl delete -f deploy/cluster_role.yaml -n $NAMESPACE
kubectl create -f deploy/cluster_role.yaml

kubectl delete -f deploy/deploy_controller.yaml -n $NAMESPACE
kubectl create -f deploy/deploy_controller.yaml

kubectl delete -f deploy/register_controller.yaml -n $NAMESPACE
kubectl create -f deploy/register_controller.yaml

