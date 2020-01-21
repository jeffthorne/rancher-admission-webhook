

def get_namespace(request):
    namespace = None
    if 'request' in request and 'namespace' in request['request']:
        namespace = request["request"]["namespace"]

    return namespace


def parse_namespace_label(namespace_object, find_label):
    labels = None

    if hasattr(namespace_object, 'metadata') and hasattr(namespace_object.metadata, 'labels'):
        if namespace_object.metadata.labels is not None and find_label in namespace_object.metadata.labels.keys():
            labels = {find_label: namespace_object.metadata.labels[find_label]}

    return labels


def logging(title, message):
    print(f"*** START {title} *****************************************************")
    print(message)
    print(f"*** END {title} *******************************************************")