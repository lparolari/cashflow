from datetime import datetime
from typing import List

import pandas as pd


class Processor:
    def __init__(self, months: List[datetime], budget_items: pd.DataFrame):
        self.months = months
        self.budget_items = budget_items
        self.out = None

    def process(self):
        df = pd.DataFrame()

        for month in self.months:
            tmp = self.budget_items.copy()

            tmp["Icon"] = tmp["icon"]
            tmp["Budget Item"] = tmp["title"]
            tmp = tmp.drop(columns=["icon", "title"])

            tmp["First of Month"] = month

            tmp["Month"] = tmp["First of Month"].apply(
                lambda x: x.strftime("%B %Y").lower()
            )
            tmp["Name"] = tmp["Month"] + " | " + tmp["Budget Item"]

            tmp = tmp.drop(columns=["Month"])
            tmp = tmp[["Name", "Icon", "Budget Item", "First of Month"]]

            df = pd.concat([df, tmp])

        self.out = df

    def unwrap(self) -> pd.DataFrame:
        if self.out is None:
            raise ValueError(
                "Data not processed yet. Did you forget to call 'process'?"
            )
        return self.out
