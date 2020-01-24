import os
from flask import Flask, request, jsonify
import base64
import jsonpatch
from kubernetes import client, config
import utils

admission_controller = Flask(__name__)
LABEL_KEY_TO_ADD_TO_DEPLOYMENTS = os.getenv('LABEL_KEY_TO_ADD_TO_DEPLOYMENTS')  #label key to insert into deployments
LABEL_KEY_LOOKING_FOR_ON_NAMESPACE = os.getenv('LABEL_KEY_LOOKING_FOR_ON_NAMESPACE')
config.load_incluster_config()
v1 = client.CoreV1Api()


def get_namespace_labels(namespace):
    resp = v1.read_namespace(namespace)
    labels = utils.parse_namespace_label(resp, LABEL_KEY_LOOKING_FOR_ON_NAMESPACE)
    utils.logging('NAMESPACE OBJECT', resp)

    return labels


@admission_controller.route('/addlabel', methods=['POST'])
def add_labels_deployment():
    request_info = request.get_json()
    utils.logging('POD OBJECT', request_info)

    namespace = utils.get_namespace(request_info)

    if namespace is not None:
        labels = get_namespace_labels(namespace)

        if labels is not None:
            projectId = labels[LABEL_KEY_LOOKING_FOR_ON_NAMESPACE]
            label_key = LABEL_KEY_TO_ADD_TO_DEPLOYMENTS.replace('/', '~1')

            utils.logging('LABELS FOUND', f"{labels} on namespace {namespace}")
            utils.logging('LABELS APPLIED', f"{label_key}={projectId} on pod template." )

            return admission_response_patch(True, "Adding Rancher ProjectId Label to Pod",
                                        json_patch=jsonpatch.JsonPatch([{"op": "add", "path": f"/metadata/labels/{label_key}", "value": projectId}]))

    utils.logging('LABEL NOT FOUND', f"{LABEL_KEY_LOOKING_FOR_ON_NAMESPACE} not found on namespace {namespace}")

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


