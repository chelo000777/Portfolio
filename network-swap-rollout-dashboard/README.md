# Network Swap Rollout Dashboard (Power BI)

Executive tracking model for a telecom network-swap rollout: it turns raw
subcontractor clock-in/out logs and milestone plan/actual dates into a
rollout-progress and field-attendance dashboard.

Built while managing subcontractor teams executing a multi-stage swap
project (site prep, equipment swap, QC, acceptance testing, reverse
logistics) for a telecom operator in Bolivia. Company names, site names,
and identifying details in this published version are anonymized;
the analytical logic and DAX are exactly as used in production.

## What it does

- Tracks 5 rollout stages per site (MOS, Swap, QC, ATP, Reverse Logistics),
  each with a **planned** and **actual** completion date
- Rolls those into stage-level and overall **completion %** and **on-time %**
- Parses subcontractor clock-in/out timestamps into daily attendance,
  punctuality, and technician headcount
- Surfaces sites that are delayed or pending, and which teams are behind

## Data model

See [`model/data_model.dbml`](model/data_model.dbml) for the full schema.
Rendered ERD: paste the DBML into [dbdiagram.io](https://dbdiagram.io).

Core tables:
- `Input_Rollout_Report` — one row per site, plan/actual date for each of
  5 rollout stages
- `Input_Clock_Report` — raw clock-in/out events per technician per site
- `Input_Total_teams` — daily headcount of active field teams
- `Calendar` — standard date table driving all time intelligence
- Several calculated tables (`SUBCON_ANALYSIS_*`, `BY_DAY_CLOCK_USE`,
  `P_subcontractor_DB`) derive attendance and roster views from the raw
  clock data without duplicating it

## Key measures

See [`measures/DAX_measures.md`](measures/DAX_measures.md) for the full
list. Highlights:

- `Overall Rollout Progress %` — actuals completed across all 5 stages,
  divided by everything planned
- `SWAP Completion %`, `QC Completion %`, `ATP Completion %`, `MOS Completion %`
- `SWAP On-Time Rate` — actual completion at or before plan date
- `Daily Active Technicians` — distinct technicians clocked in
- `Punctuality Rate` — share of clock-ins before the 9:30 cutoff
- `Sites Pending SWAP` — plan minus actual, i.e. remaining backlog

These live in a dedicated `_KPIs_Executive` measures table so they're easy
to find in the field list and don't clutter the input tables.

The user prompt is empty, so I cannot determine the primary language. However, based on the thinking block alone, here is a summary:

Navigated user toward menu options for file deletionThe user prompt is empty, so I cannot determine the primary language. However, based on the thinking block alone, here is a summary:

Navigated user toward menu options for file deletionThis edit view doesn't have a delete option here. Let's back out and use a different path:

Click "Cancel changes" (top right) to leave the editor
You'll land back on the file view for screenshots
Look at the very top right of the page, next to the breadcrumb (Portfolio / network-swap-rollout-dashboard / screenshots) — there should be a "..." (three dots) icon there, separate from the toolbar with Raw/copy/edit
Click that "..." — it should give you a Delete file option directly

If that "..." isn't there or doesn't have delete, here's a guaranteed alternative:

Go to the network-swap-rollout-dashboard folder listing (click the folder name in the breadcrumb)
Check the box/checkbox next to screenshots if one appears when hovering, or just click into the file once more
In the file view, use Raw button first to confirm it's the empty file, then use the pencil (edit) icon → this time instead of typing anything, look for a trash can icon directly next to the pencil icon in that same toolbar row (not inside the dropdown) — it's easy to miss since it's a separate icon, not part of the "Edit file..." dropdown menu.

If none of this surfaces a delete button, tell me and I'll give you the git command line equivalent instead (a two-line git rm + git commit you can run if you have the repo cloned, or via GitHub Desktop if you use that).done I want to create a screenshot folderStrategized adding screenshots folder with dashboard imagesStrategized adding screenshots folder with dashboard imagesGitHub doesn't let you create an empty folder directly — a folder only exists once it contains a file. Here's the clean way to do it:
Option A — create it while uploading images (recommended, since you'll want actual screenshots in it anyway)

Go into network-swap-rollout-dashboard
Click Add file → Upload files
Drag in your screenshot image(s) (e.g. exported PNGs of the dashboard from Power BI Desktop — File → Export → Export to Image, or just a Snipping Tool capture)
Before committing, in the file list that appears you can rename each file's path by clicking on it and typing screenshots/your-filename.png — this creates the folder and puts the file inside in one step
Commit directly to main

Option B — create the folder first, then add images

Click Add file → Create new file
In the filename box, type screenshots/dashboard_overview.png — but note the web editor is text-only, so this only works if you're creating a placeholder text file, not an image. Skip this for images; use Option A instead.

What to put in it
If you want, export a real screenshot from Power BI Desktop now that your Executive KPI Summary page is styled — that's the most authentic thing for the portfolio. Alternatively, I can generate a static image version of the dashboard_preview.html mockup you already have, sized for GitHub, if you want a placeholder while you get the real Power BI screenshot. Want me to do that?Reorganized file structure for image storage organizationReorganized file structure for image storage organizationYou're right there. To put both files into a screenshots folder in this same step:

Click on the filename text "DASHBOARD.png" in that list — it should become editable
Change it to screenshots/DASHBOARD.png
Do the same for the second one: click "DATA_MODEL.png" and change it to screenshots/DATA_MODEL.png
Add a commit message like "Add dashboard screenshots"
Leave "Commit directly to the main branch" selected
Click Commit changes

That single commit will create the screenshots folder with both images inside it — no separate empty-folder step needed.require to modify to show the screenshots:
# Network Swap Rollout Dashboard (Power BI)
Executive tracking model for a telecom network-swap rollout: it turns raw
subcontractor clock-in/out logs and milestone plan/actual dates into a
rollout-progress and field-attendance dashboard.
Built while managing subcontractor teams executing a multi-stage swap
project (site prep, equipment swap, QC, acceptance testing, reverse
logistics) for a telecom operator in Bolivia. Company names, site names,
and identifying details in this published version are anonymized;
the analytical logic and DAX are exactly as used in production.
## What it does
- Tracks 5 rollout stages per site (MOS, Swap, QC, ATP, Reverse Logistics),
  each with a **planned** and **actual** completion date
- Rolls those into stage-level and overall **completion %** and **on-time %**
- Parses subcontractor clock-in/out timestamps into daily attendance,
  punctuality, and technician headcount
- Surfaces sites that are delayed or pending, and which teams are behind
## Data model
See [model/data_model.dbml](model/data_model.dbml) for the full schema.
Rendered ERD: paste the DBML into [dbdiagram.io](https://dbdiagram.io).
Core tables:
- Input_Rollout_Report — one row per site, plan/actual date for each of
  5 rollout stages
- Input_Clock_Report — raw clock-in/out events per technician per site
- Input_Total_teams — daily headcount of active field teams
- Calendar — standard date table driving all time intelligence
- Several calculated tables (SUBCON_ANALYSIS_*, BY_DAY_CLOCK_USE,
  P_subcontractor_DB) derive attendance and roster views from the raw
  clock data without duplicating it
## Key measures
See [measures/DAX_measures.md](measures/DAX_measures.md) for the full
list. Highlights:
- Overall Rollout Progress % — actuals completed across all 5 stages,
  divided by everything planned
- SWAP Completion %, QC Completion %, ATP Completion %, MOS Completion %
- SWAP On-Time Rate — actual completion at or before plan date
- Daily Active Technicians — distinct technicians clocked in
- Punctuality Rate — share of clock-ins before the 9:30 cutoff
- Sites Pending SWAP — plan minus actual, i.e. remaining backlog
These live in a dedicated _KPIs_Executive measures table so they're easy
to find in the field list and don't clutter the input tables.
## Dashboard
An executive summary page in the Power BI report itself: KPI cards
(rollout progress, sites pending, active technicians, punctuality),
a plan-vs-actual swap trend, a completion-share donut by rollout stage,
and a weekday technician-attendance bar chart — dark themed to match
the preview below.
See [preview/dashboard_preview.html](preview/dashboard_preview.html)
for a standalone HTML preview (sample data — open directly in a browser
or embed via GitHub Pages). The live Power BI report link is in my
[portfolio index](https://github.com/chelo000777/portfolio).
## Tools
Power BI (Power Query, DAX, PBIP project format), modeled in Power BI
Desktop. Sanitized company/site/employee names throughout; see
model/data_model.dbml for the generic column and table names used.
## Author
Juan Marcelo Párraga Calizaya — [LinkedIn](https://linkedin.com/in/marcelo-parraga) · [Portfolio](https://github.com/chelo000777/portfolio)Show moreOrganized screenshots and integrated visual documentation into READMEOrganized screenshots and integrated visual documentation into READMEHere's the updated README with a screenshots section added — insert this right after the ## Dashboard section (before ## Tools):
markdown## Dashboard

An executive summary page in the Power BI report itself: KPI cards
(rollout progress, sites pending, active technicians, punctuality),
a plan-vs-actual swap trend, a completion-share donut by rollout stage,
and a weekday technician-attendance bar chart — dark themed to match
the preview below.

See [`preview/dashboard_preview.html`](preview/dashboard_preview.html)
for a standalone HTML preview (sample data — open directly in a browser
or embed via GitHub Pages). The live Power BI report link is in my
[portfolio index](https://github.com/chelo000777/portfolio).

## Screenshots

**Executive dashboard**
![Executive KPI Summary dashboard](screenshots/DASHBOARD.png)

**Data model**
![Data model diagram](screenshots/DATA_MODEL.png)

## Tools

Power BI (Power Query, DAX, PBIP project format), modeled in Power BI
Desktop. Sanitized company/site/employee names throughout; see
`model/data_model.dbml` for the generic column and table names used.

## Author

Juan Marcelo Párraga Calizaya — [LinkedIn](https://linkedin.com/in/marcelo-parraga) · [Portfolio](https://github.com/chelo000777/portfolio)
