# Octy ML Pipeline (Offline)

This folder trains a simple Logistic Regression model (scikit-learn) that predicts a proxy "motivation drop" label for the next day.

## Inputs
Export 3 JSON files from Firestore (per user):
- `events.json`: array of `{type,dateKey,hour,data}` (from `users/{uid}/events`)
- `habit_logs.json`: array of `{habitId,dateKey,completed}` (from `users/{uid}/habitLogs`)
- `habits.json`: array of `{id,goalPerWeek,currentStreak}` (from `users/{uid}/habits`)

## Build dataset
`python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt`

`python build_dataset.py --events events.json --habit-logs habit_logs.json --habits habits.json --out dataset.csv --days 60`

## Train model
`python train_logreg.py --csv dataset.csv --out ../../assets/ml/model.json`

## Enable in app
Run the app with:
`flutter run --dart-define=OCTY_USE_ML=true`

Without `OCTY_USE_ML=true`, the app keeps using the heuristic risk engine.
