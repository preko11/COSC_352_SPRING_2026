import pandas as pd
import os

base = os.path.dirname(__file__)

requests = pd.read_csv(os.path.join(base, "../data/311.csv"))

print("311 dataset loaded successfully")
print(requests.head())
