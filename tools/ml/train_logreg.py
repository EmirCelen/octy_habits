import argparse
import json

import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score


FEATURES = [
    "missing_ratio_avg",
    "weekly_adherence_avg",
    "streak_penalty_avg",
    "done_today_ratio",
    "login_regularity",
    "assistant_engagement",
    "evening_usage_pattern",
    "total_habits",
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    df = df.dropna()

    X = df[FEATURES].astype(float)
    y = df["label_drop"].astype(int)

    if len(df) < 30 or y.nunique() < 2:
        raise SystemExit("Not enough data or labels to train.")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )

    model = LogisticRegression(max_iter=200)
    model.fit(X_train, y_train)

    prob = model.predict_proba(X_test)[:, 1]
    auc = roc_auc_score(y_test, prob)

    out = {
        "intercept": float(model.intercept_[0]),
        "weights": {k: float(v) for k, v in zip(FEATURES, model.coef_[0])},
        "metrics": {"roc_auc": float(auc), "rows": int(len(df))},
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)

    print("Wrote", args.out)
    print("ROC AUC", auc)


if __name__ == "__main__":
    main()
