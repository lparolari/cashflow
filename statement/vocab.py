import json


class Vocab(dict):
    def __init__(self, path: str, **kwargs):
        self.path = path
        super().__init__(**kwargs)

    def save(self):
        with open(self.path, "w") as f:
            json.dump(self, f, indent=4)

    @staticmethod
    def from_json(path: str) -> "Vocab":
        with open(path) as f:
            return Vocab(path, **json.load(f))
