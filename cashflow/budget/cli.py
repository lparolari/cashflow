import argparse
from datetime import datetime
from typing import List

import pandas as pd
from dateutil.relativedelta import relativedelta

from cashflow.budget.processor import Processor


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-m",
        "--month",
        type=str,
        default="current",
        help="Month to generate budget items for. Specify either 'current', 'next', or month date with format '%%Y-%%m' (example: 2023-03). Default: 'current'.",
    )
    parser.add_argument(
        "--budget-items-path", type=str, default="assets/budget_items.json"
    )
    parser.add_argument("output", type=str)

    args = parser.parse_args()

    budget_items_path = args.budget_items_path
    month = parse_month(args.month)
    output = args.output

    budget_items = pd.read_json(budget_items_path)

    processor = Processor([month], budget_items=budget_items)
    processor.process()

    out = processor.unwrap()

    out.to_csv(output, index=False)


def parse_month(month: str) -> datetime:
    replace = {"day": 1, "hour": 0, "minute": 0, "second": 0, "microsecond": 0}

    if month == "current":
        return datetime.now().replace(**replace)
    elif month == "next":
        return datetime.now().replace(**replace) + relativedelta(months=1)
    else:
        return datetime.strptime(month, "%Y-%m").replace(**replace)


if __name__ == "__main__":
    main()
