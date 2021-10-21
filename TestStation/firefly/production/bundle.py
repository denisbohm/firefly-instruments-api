import os

default_bundle = None


class Bundle:

    @staticmethod
    def set_default_bundle(roots):
        global default_bundle
        default_bundle = Bundle(roots)

    @staticmethod
    def get_default_bundle():
        return default_bundle

    def __init__(self, roots):
        self.roots = roots

    def path_for_resource(self, resource):
        for root in self.roots:
            path = os.path.join(root, resource)
            if os.path.isfile(path):
                return path
        raise IOError(f"resource not found: {resource}")
