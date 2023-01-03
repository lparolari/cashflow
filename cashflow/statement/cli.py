import argparse

import pandas as pd

from cashflow.statement.budget import BudgetClassifier
from cashflow.statement.category import CategoryClassifier
from cashflow.statement.processor import get_processor_cls
from cashflow.statement.vocab import Vocab


def main():
    parser = argparse.ArgumentParser(
        description="Process a CSV bank statement to a Notion Cashflow Manager importable dataset"
    )
    parser.add_argument("input", help="Path to statement to process")
    parser.add_argument("output", help="Path to processed statement")
    parser.add_argument(
        "--processor",
        choices=["revolut", "intesa", "vivid"],
        required=True,
        help="Statement processor to use",
    )
    parser.add_argument(
        "--category-vocab-path",
        default=str("assets/category_vocab.json"),
        help="Path to a JSON file containing the category vocabulary",
    )
    parser.add_argument(
        "--budget-vocab-path",
        default=str("assets/budget_vocab.json"),
        help="Path to a JSON file containing the budget vocabulary",
    )
    parser.add_argument(
        "--retrain",
        default=False,
        action="store_true",
        help="If true, prompt the user to insert out of vocabulary words for both categories and budgets",
    )

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
