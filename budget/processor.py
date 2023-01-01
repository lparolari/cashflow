from datetime import datetime

import pandas as pd


class Processor:
    def __init__(self, df: pd.DataFrame, budget_items: pd.DataFrame):
        self.inp = df
        self.out = None
        self.budget_items = budget_items

    def process(self):
        inp = self.inp.copy()

        dates = inp["Date"]
        dates = dates.apply(lambda x: datetime.strptime(x, "%Y-%m-%d %H:%M:%S"))
        dates = dates.apply(lambda x: pd.to_datetime(x).to_period("M").start_time)
        dates = dates.unique()

        df = pd.DataFrame()
        
        for date in dates:
            tmp = self.budget_items.copy()

            tmp["Icon"] = tmp["icon"]
            tmp["Budget Item"] = tmp["title"]
            tmp = tmp.drop(columns=["icon", "title"])

            tmp["First of Month"] = date
            
            tmp["Month"] = tmp["First of Month"].apply(lambda x: x.strftime("%B %Y").lower())
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
