import os
from pprint import pprint

def parse_namespace_label(namespace_object, find_label):
    labels = None

    if hasattr(namespace_object, 'metadata') and hasattr(namespace_object.metadata, 'labels'):
        if namespace_object.metadata.labels is not None and find_label in namespace_object.metadata.labels.keys():
            labels = {find_label: namespace_object.metadata.labels[find_label]}

    return labels


def debug(title, message):
    if os.environ.get("WEBHOOK_DEBUG", "0") == "1":
        print(f"*** START {title} *****************************************************")
        pprint(message)
        print(f"*** END {title} *******************************************************")
