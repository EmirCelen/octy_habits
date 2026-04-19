import argparse
import json
from datetime import datetime, timedelta

import pandas as pd


def _date_key(dt: datetime) -> str:
    return dt.strftime("%Y%m%d")


def load_json(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_features(events, habit_logs, habits, days=30):
    # events: list of {type,dateKey,hour,data}
    # habit_logs: list of {habitId,dateKey,completed}
    # habits: list of {id,goalPerWeek,currentStreak}
    habits_by_id = {h["id"]: h for h in habits}

    # aggregate per day
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    start = today - timedelta(days=days - 1)

    # completion map: day -> habitId -> completed
    logs_by_day = {}
    for row in habit_logs:
        if not row.get("completed", False):
            continue
        dk = row.get("dateKey")
        hid = row.get("habitId")
        if not dk or not hid:
            continue
        logs_by_day.setdefault(dk, set()).add(hid)

    # weekly done counts proxy: last 7 days rolling window
    all_days = [start + timedelta(days=i) for i in range(days)]

    # app_open days
    app_open_days = set(e.get("dateKey") for e in events if e.get("type") == "app_open")

    # assistant msg counts per day
    assistant_by_day = {}
    for e in events:
        if e.get("type") != "assistant_message":
            continue
        dk = e.get("dateKey")
        if not dk:
            continue
        assistant_by_day[dk] = assistant_by_day.get(dk, 0) + 1

    # usage hour pattern (evening ratio)
    evening = 0
    for e in events:
        h = int(e.get("hour", 0) or 0)
        if 18 <= h <= 23:
            evening += 1
    evening_usage_pattern = (evening / max(1, len(events)))

    rows = []
    for d in all_days:
        dk = _date_key(d)
        completed_today = logs_by_day.get(dk, set())
        total_habits = len(habits)
        done_today = len(completed_today)
        done_today_ratio = 0.0 if total_habits == 0 else done_today / total_habits

        # rolling 7 day window adherence
        window_start = d - timedelta(days=6)
        window_keys = {_date_key(window_start + timedelta(days=i)) for i in range(7)}
        weekly_done_total = 0
        for wk in window_keys:
            weekly_done_total += len(logs_by_day.get(wk, set()))

        # missing ratio avg and adherence avg require per-habit goal. We'll approximate using goal sum.
        goal_sum = 0
        for h in habits:
            goal_sum += max(1, int(h.get("goalPerWeek", 1) or 1))
        weekly_adherence_avg = 0.0 if goal_sum == 0 else min(1.0, weekly_done_total / goal_sum)
        missing_ratio_avg = 1.0 - weekly_adherence_avg

        # streak penalty avg from habit aggregates
        streak_penalty_avg = 0.0
        for h in habits:
            st = int(h.get("currentStreak", 0) or 0)
            if st <= 0:
                streak_penalty_avg += 1.0
            elif st <= 2:
                streak_penalty_avg += 0.55
            else:
                streak_penalty_avg += 0.2
        streak_penalty_avg = 0.0 if total_habits == 0 else streak_penalty_avg / total_habits

        login_days_window = sum(1 for wk in window_keys if wk in app_open_days)
        login_regularity = login_days_window / 7.0

        assistant_msgs_window = 0
        for wk in window_keys:
            assistant_msgs_window += assistant_by_day.get(wk, 0)
        assistant_engagement = min(1.0, assistant_msgs_window / 7.0)

        # label: motivation drop proxy = low completion tomorrow
        next_day = _date_key(d + timedelta(days=1))
        done_tomorrow = len(logs_by_day.get(next_day, set()))
        done_tomorrow_ratio = 0.0 if total_habits == 0 else done_tomorrow / total_habits
        label_drop = 1 if done_tomorrow_ratio < 0.34 else 0

        rows.append(
            {
                "dateKey": dk,
                "missing_ratio_avg": missing_ratio_avg,
                "weekly_adherence_avg": weekly_adherence_avg,
                "streak_penalty_avg": streak_penalty_avg,
                "done_today_ratio": done_today_ratio,
                "login_regularity": login_regularity,
                "assistant_engagement": assistant_engagement,
                "evening_usage_pattern": evening_usage_pattern,
                "total_habits": min(1.0, total_habits / 50.0),
                "label_drop": label_drop,
            }
        )

    return pd.DataFrame(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--events", required=True)
    ap.add_argument("--habit-logs", required=True)
    ap.add_argument("--habits", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--days", type=int, default=30)
    args = ap.parse_args()

    events = load_json(args.events)
    habit_logs = load_json(args.habit_logs)
    habits = load_json(args.habits)

    df = build_features(events, habit_logs, habits, days=args.days)
    df.to_csv(args.out, index=False)


if __name__ == "__main__":
    main()
