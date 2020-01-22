import unittest

from app.utils import get_namespace, parse_namespace_label
import kubernetes


k8s_deploy_object = {'kind': 'AdmissionReview', 'apiVersion': 'admission.k8s.io/v1beta1', 'request': {'uid': '15e2450a-3c79-11ea-9890-02db173a0ec2', 'kind': {'group': 'apps', 'version': 'v1', 'kind': 'Deployment'}, 'resource': {'group': 'apps', 'version': 'v1', 'resource': 'deployments'}, 'namespace': 'jeffsbooks', 'operation': 'CREATE', 'userInfo': {'username': 'kubernetes-admin', 'groups': ['system:masters', 'system:authenticated']}, 'object': {'metadata': {'name': 'jeffsbooks', 'namespace': 'jeffsbooks', 'creationTimestamp': None, 'labels': {'app': 'jeffsbooks'}, 'annotations': {'kubectl.kubernetes.io/last-applied-configuration': '{"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app":"jeffsbooks"},"name":"jeffsbooks","namespace":"jeffsbooks"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"jeffsbooks"}},"template":{"metadata":{"labels":{"app":"jeffsbooks"}},"spec":{"containers":[{"env":[{"name":"POSTGRES_HOST","value":"postgres.postgres"},{"name":"FLASK_ENV","value":"production"},{"name":"azure_username","value":"{jeffsbooks_azure.username}"},{"name":"POSTGRES_USER","value":"{jeffs_hashi.jeffsbooks/postgres.username}"},{"name":"POSTGRES_PASSWORD","value":"{jeffs_hashi.jeffsbooks/postgres.password}"},{"name":"POSTGRES_USER_FROM_K8S_SECRET","valueFrom":{"secretKeyRef":{"key":"POSTGRES_USER","name":"postgres-config"}}},{"name":"POSTGRES_PASSWORD_FROM_K8S_SECRET","valueFrom":{"secretKeyRef":{"key":"POSTGRES_PASSWORD","name":"postgres-config"}}}],"image":"jeffthorne/books:latest","imagePullPolicy":"Always","name":"jeffsbooks","ports":[{"containerPort":8088,"name":"flask"}]}],"imagePullSecrets":[{"name":"dockerhub"}]}}}}\n'}}, 'spec': {'replicas': 1, 'selector': {'matchLabels': {'app': 'jeffsbooks'}}, 'template': {'metadata': {'creationTimestamp': None, 'labels': {'app': 'jeffsbooks'}}, 'spec': {'containers': [{'name': 'jeffsbooks', 'image': 'jeffthorne/books:latest', 'ports': [{'name': 'flask', 'containerPort': 8088, 'protocol': 'TCP'}], 'env': [{'name': 'POSTGRES_HOST', 'value': 'postgres.postgres'}, {'name': 'FLASK_ENV', 'value': 'production'}, {'name': 'azure_username', 'value': '{jeffsbooks_azure.username}'}, {'name': 'POSTGRES_USER', 'value': '{jeffs_hashi.jeffsbooks/postgres.username}'}, {'name': 'POSTGRES_PASSWORD', 'value': '{jeffs_hashi.jeffsbooks/postgres.password}'}, {'name': 'POSTGRES_USER_FROM_K8S_SECRET', 'valueFrom': {'secretKeyRef': {'name': 'postgres-config', 'key': 'POSTGRES_USER'}}}, {'name': 'POSTGRES_PASSWORD_FROM_K8S_SECRET', 'valueFrom': {'secretKeyRef': {'name': 'postgres-config', 'key': 'POSTGRES_PASSWORD'}}}], 'resources': {}, 'terminationMessagePath': '/dev/termination-log', 'terminationMessagePolicy': 'File', 'imagePullPolicy': 'Always'}], 'restartPolicy': 'Always', 'terminationGracePeriodSeconds': 30, 'dnsPolicy': 'ClusterFirst', 'securityContext': {}, 'imagePullSecrets': [{'name': 'dockerhub'}], 'schedulerName': 'default-scheduler'}}, 'strategy': {'type': 'RollingUpdate', 'rollingUpdate': {'maxUnavailable': '25%', 'maxSurge': '25%'}}, 'revisionHistoryLimit': 10, 'progressDeadlineSeconds': 600}, 'status': {}}, 'oldObject': None, 'dryRun': False}}
namespace_obj = {'api_version': 'v1',
 'kind': 'Namespace',
 'metadata': {'annotations': {'cattle.io/status': '{"Conditions":[{"Type":"ResourceQuotaInit","Status":"True","Message":"","LastUpdateTime":"2020-01-20T21:02:35Z"},{"Type":"InitialRolesPopulated","Status":"True","Message":"","LastUpdateTime":"2020-01-20T21:02:37Z"}]}',
                              'field.cattle.io/projectId': 'c-prhdq:p-fblnp',
                              'lifecycle.cattle.io/create.namespace-auth': 'true'},
              'cluster_name': None,
              'creation_timestamp': 'fake date',
              'deletion_grace_period_seconds': None,
              'deletion_timestamp': None,
              'finalizers': ['controller.cattle.io/namespace-auth'],
              'generate_name': None,
              'generation': None,
              'initializers': None,
              'labels': {'customer': 'a', 'field.cattle.io/projectId': 'p-fblnp'},
              'managed_fields': None,
              'name': 'jeffsbooks',
              'namespace': None,
              'owner_references': None,
              'resource_version': '9738523',
              'self_link': '/api/v1/namespaces/jeffsbooks',
              'uid': 'c65ac773-3c4c-11e9-9c9e-02db173a0ec2'},
 'spec': {'finalizers': ['kubernetes']},
 'status': {'phase': 'Active'}}

class TestRequestObject(unittest.TestCase):

    def test_get_namespace(self):
        namespace = get_namespace(k8s_deploy_object)
        assert namespace == 'jeffsbooks'

    def test_get_label(self):
        label_to_look_for = 'field.cattle.io/projectId'
        metadata = kubernetes.client.models.V1ObjectMeta(**namespace_obj['metadata'])
        k8s_namespace_obj = kubernetes.client.models.v1_namespace.V1Namespace(api_version=namespace_obj['api_version'],
                                                                              kind=namespace_obj['kind'], metadata=metadata,
                                                                              spec=namespace_obj['spec'], status=namespace_obj['status'])

        labels = parse_namespace_label(k8s_namespace_obj, label_to_look_for)
        assert label_to_look_for in labels
        assert labels[label_to_look_for] == 'p-fblnp'


if __name__ == '__main__':
    unittest.main()