import argparse

import pandas as pd

from cashflow.budget import BudgetClassifier
from cashflow.category import CategoryClassifier
from cashflow.processor import get_processor_cls
from cashflow.vocab import Vocab

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument(
        "--processor", choices=["revolut", "intesa", "vivid"], required=True
    )
    parser.add_argument("--vocab-path", default=str("assets/vocab.json"))
    parser.add_argument("--retrain", default=False, action="store_true")

    args = parser.parse_args()

    input_file = args.input
    output_file = args.output
    processor = args.processor
    vocab_path = args.vocab_path
    retrain = args.retrain

    category_classifier = CategoryClassifier(
        Vocab.from_json(vocab_path), retrain=retrain
    )

    budget_classifier = BudgetClassifier()

    df = pd.read_csv(input_file)

    processor_cls = get_processor_cls(processor)
    processor = processor_cls(
        df, category_classifier=category_classifier, budget_classifier=budget_classifier
    )

    processor.process()

    df_processed = processor.unwrap()
    df_processed.to_csv(output_file, index=False)
