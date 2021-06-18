import os

default_bundle = None


class Bundle:

    @staticmethod
    def set_default_bundle(root):
        global default_bundle
        default_bundle = Bundle(root)

    @staticmethod
    def get_default_bundle():
        return default_bundle

    def __init__(self, root):
        self.root = root

    def path_for_resource(self, resource):
        return os.path.join(self.root, resource)
