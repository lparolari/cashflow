from cashflow.statement.vocab import Vocab


class BudgetClassifier:
    def __init__(self, vocab: Vocab, retrain: bool = False):
        self.vocab = vocab
        self.retrain = retrain
        self.unknown = "unknown"

    def classify(self, data: dict) -> str:
        description = data["Description"]
        category = data["Category"]

        for keyword, budget in self.vocab.items():
            if keyword in category.lower():
                return budget

        if self.retrain:
            print(
                f"Unknown budget for '{category}' ({description}), enter a budget? [y/N] ",
                end="",
            )

            if input() != "y":
                return self.unknown

            keyword = input("Keyword: ")
            budget = input(f"Budget: ")

            self.vocab[keyword] = budget
            self.vocab.save()

            return budget

        return self.unknown
