from cashflow.statement.vocab import Vocab


class CategoryClassifier:
    def __init__(self, vocab: Vocab, retrain: bool = False):
        self.vocab = vocab
        self.retrain = retrain
        self.unknown = "unknown"

    def classify(self, description: str) -> str:
        for keyword, category in self.vocab.items():
            if keyword in description.lower():
                return category

        if self.retrain:
            print(
                f"Unknown category for '{description}', enter a category? [y/N] ",
                end="",
            )

            if input() != "y":
                return self.unknown

            keyword = input("Keyword: ")
            category = input(f"Category: ")

            self.vocab[keyword] = category
            self.vocab.save()

            return category

        return self.unknown
