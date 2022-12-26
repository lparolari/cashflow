import argparse

import pandas as pd

from cashflow.budget import BudgetClassifier
from cashflow.category import CategoryClassifier
from cashflow.processor import get_processor_cls
from cashflow.vocab import Vocab


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument(
        "--processor", choices=["revolut", "intesa", "vivid"], required=True
    )
    parser.add_argument(
        "--category-vocab-path", default=str("assets/category_vocab.json")
    )
    parser.add_argument("--budget-vocab-path", default=str("assets/budget_vocab.json"))
    parser.add_argument("--retrain", default=False, action="store_true")

    args = parser.parse_args()

    input_file = args.input
    output_file = args.output
    processor = args.processor
    category_vocab_path = args.category_vocab_path
    budget_vocab_path = args.budget_vocab_path
    retrain = args.retrain

    category_classifier = CategoryClassifier(
        Vocab.from_json(category_vocab_path), retrain=retrain
    )

    budget_classifier = BudgetClassifier(
        Vocab.from_json(budget_vocab_path), retrain=retrain
    )

    df = pd.read_csv(input_file)

    processor_cls = get_processor_cls(processor)
    processor = processor_cls(
        df, category_classifier=category_classifier, budget_classifier=budget_classifier
    )

    processor.process()

    df_processed = processor.unwrap()
    df_processed.to_csv(output_file, index=False)


if __name__ == "__main__":
    main()
