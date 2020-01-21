import os
from flask import Flask, request, jsonify
import base64
import jsonpatch
from kubernetes import client, config

admission_controller = Flask(__name__)

running_in_cluster = True

LABEL_KEY = os.getenv('LABEL_KEY')  #label key to insert into deployments
config.load_incluster_config()
v1 = client.CoreV1Api()


def get_namespace(request):
    namespace = None
    if 'request' in request and 'namespace' in request['request']:
        namespace = request["request"]["namespace"]

    return namespace


def get_namespace_labels(namespace):
    resp = v1.read_namespace(namespace)
    print("*** START NAMESPACE OBJECT *****************************************************")
    print(resp)
    print("*** END NAMESPACE OBJECT *******************************************************")

    if hasattr(resp, 'metadata') and hasattr(resp.metadata, 'labels'):
        if resp.metadata.labels is not None and 'field.cattle.io/projectId' in resp.metadata.labels.keys():
            labels = {'field.cattle.io/projectId': resp.metadata.labels['field.cattle.io/projectId']}

    return labels



@admission_controller.route('/add/labels/deployments', methods=['POST'])
def add_labels_deployment():
    request_info = request.get_json()
    print("*** START DEPLOYMENT OBJECT *****************************************************")
    print(request_info)
    print("*** END DEPLOYMENT OBJECT *******************************************************")

    namespace = get_namespace(request_info)
    projectId = ""

    if namespace is not None:
        labels = get_namespace_labels(namespace)
        if labels is not None:
            projectId = labels[LABEL_KEY]
        print("*** START LABELS FOUND *******************************************************")
        print(labels)
        print("*** END LABELS FOUND *******************************************************")

    if labels is not None:
        label_key = LABEL_KEY.replace('/', '~1')
        return admission_response_patch(True, "Adding Rancher ProjectId Label to Deployment",
                                    json_patch=jsonpatch.JsonPatch([{"op": "add", "path": f"/spec/template/metadata/labels/{label_key}",
                                                                     "value": projectId}]))
    else:
        return jsonify({"response": {"allowed": True, "status": {"message": "No Rancher ProjectId found"}}})


def admission_response_patch(allowed, message, json_patch):
    base64_patch = base64.b64encode(json_patch.to_string().encode("utf-8")).decode("utf-8")
    return jsonify({"response": {"allowed": allowed,
                                 "status": {"message": message},
                                 "patchType": "JSONPatch",
                                 "patch": base64_patch}})


@admission_controller.route('/liveness', methods=['GET'])
def liveness():
    return "Yes"


if __name__ == '__main__':
    admission_controller.run(host='0.0.0.0', port=8443, ssl_context=("/certs/server.crt", "/certs/server.key"))
else:
    admission_controller.run(host='0.0.0.0', port=8443, ssl_context=("/certs/server.crt", "/certs/server.key"))


