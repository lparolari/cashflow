import argparse
import pandas as pd

from cashflow.budget.processor import Processor


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--budget-items-path", type=str, default="assets/budget_items.json")
    parser.add_argument("input", type=str)
    parser.add_argument("output", type=str)
    
    args = parser.parse_args()

    budget_items_path = args.budget_items_path
    inp = args.input
    output = args.output

    budget_items = pd.read_json(budget_items_path)
    
    df = pd.read_csv(inp)

    processor = Processor(df, budget_items=budget_items)
    processor.process()

    out = processor.unwrap()

    out.to_csv(output, index=False)


if __name__ == "__main__":
    main()
