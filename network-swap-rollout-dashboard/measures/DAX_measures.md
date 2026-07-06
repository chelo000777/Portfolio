# DAX measures

## Executive KPIs (`_KPIs_Executive`)

New measures added for the executive dashboard view. Grouped in their own
table so the rollout and attendance stage measures stay uncluttered.

```dax
MOS Completion % = DIVIDE([02_MOS Actual], [01_MOS Plan])

SWAP Completion % = DIVIDE([04_SWAP Actual], [03_SWAP Plan])

QC Completion % = DIVIDE([06_QC Actual], [05_QC Plan])

ATP Completion % = DIVIDE([08_ATP Actual], [07_ATP Plan])

Overall Rollout Progress % =
DIVIDE(
    [02_MOS Actual] + [04_SWAP Actual] + [06_QC Actual] + [08_ATP Actual],
    [01_MOS Plan] + [03_SWAP Plan] + [05_QC Plan] + [07_ATP Plan]
)

Sites Pending SWAP = [03_SWAP Plan] - [04_SWAP Actual]

SWAP On-Time Rate =
DIVIDE(
    CALCULATE(
        COUNTROWS(Input_Rollout_Report),
        NOT ISBLANK(Input_Rollout_Report[TDI(SWAP)_Actual End Date]),
        Input_Rollout_Report[TDI(SWAP)_Actual End Date]
            <= Input_Rollout_Report[TDI(SWAP)_Plan End Date]
    ),
    [04_SWAP Actual]
)

Daily Active Technicians =
CALCULATE(
    DISTINCTCOUNT(Input_Clock_Report[Name]),
    Input_Clock_Report[Clock In/Out] = "Clock in"
)

Punctuality Rate =
VAR OnTimeClockIns =
    CALCULATE(
        COUNTROWS(SUBCON_ANALYSIS_BY_DAY_2),
        NOT ISBLANK(SUBCON_ANALYSIS_BY_DAY_2[Clock_In_2]),
        SUBCON_ANALYSIS_BY_DAY_2[ClockInColor] = "#000000"
    )
VAR TotalClockIns =
    CALCULATE(
        COUNTROWS(SUBCON_ANALYSIS_BY_DAY_2),
        NOT ISBLANK(SUBCON_ANALYSIS_BY_DAY_2[Clock_In_2])
    )
RETURN
    DIVIDE(OnTimeClockIns, TotalClockIns)

Avg Teams Deployed = AVERAGE(Input_Total_teams[QTY_TEAMS])

Stage Completion Count =
SWITCH(
    SELECTEDVALUE('_StageShare'[Stage]),
    "MOS", [02_MOS Actual],
    "Swap", [04_SWAP Actual],
    "QC", [06_QC Actual],
    "ATP", [08_ATP Actual]
)
```

`Stage Completion Count` powers the "completion share by stage" donut. It
reads the category from a small disconnected table (`_StageShare`) and
switches to the matching stage's actual-completion measure — a standard
disconnected-table pattern, so the donut doesn't need a physical
relationship to `Input_Rollout_Report`.

## Existing rollout stage measures (`Input_Rollout_Report`)

Plan vs actual counts per stage, using `USERELATIONSHIP` since each stage
has its own inactive date relationship to `Calendar`:

```dax
01_MOS Plan =
CALCULATE(
    COUNTROWS(Input_Rollout_Report),
    USERELATIONSHIP(Input_Rollout_Report[MOS_Plan End Date], Calendar[Date])
)

02_MOS Actual =
CALCULATE(
    COUNTROWS(Input_Rollout_Report),
    USERELATIONSHIP(Input_Rollout_Report[MOS_Actual End Date], Calendar[Date]),
    NOT ISBLANK(Input_Rollout_Report[MOS_Actual End Date])
)
```

The same Plan/Actual pair repeats for `03/04_SWAP`, `05/06_QC`,
`07/08_ATP`, and `09/10_Rev_Logistic`, plus delay flags like
`13_MOS_DELAYED` (planned before today, no actual yet) and on-time flags
like `27_MOS_ON_TIME` (actual at or before plan).

## Supporting tables for the dashboard

Two small calculated tables exist only to feed the executive dashboard —
neither touches the raw input tables.

**`_StageShare`** — a 4-row disconnected table (`MOS`, `Swap`, `QC`, `ATP`)
that drives the stage-completion donut's category axis, paired with
`Stage Completion Count` above.

**`_WeekdayAttendance`** — a calculated table built from
`Input_Clock_Report` via `ADDCOLUMNS` + `SUMMARIZE`, extracting the
weekday name and a distinct technician count per weekday:

```dax
_WeekdayAttendance =
SUMMARIZE(
    ADDCOLUMNS(
        Input_Clock_Report,
        "Weekday", FORMAT(Input_Clock_Report[Clock Time], "ddd"),
        "WeekdayNum", WEEKDAY(Input_Clock_Report[Clock Time], 2)
    ),
    [Weekday],
    [WeekdayNum],
    "Technicians", DISTINCTCOUNT(Input_Clock_Report[Name])
)
```

## Attendance measures (`SUBCON_ANALYSIS_BY_DAY_2`)

Clock time is split into a "clock in" column and a "clock out" column so
both can be aggregated independently per technician, per site, per day —
then `ClockInColor` flags late arrivals (after 9:30) for conditional
formatting in the report.
