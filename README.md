# 5G Potential User Segmentation & NR Activation Analysis

**Domain:** Telecommunications · Commercial Analytics  
**Scale:** Millions of CRM subscribers · 31-day traffic analysis period  
**Stack:** HiveSQL · Hadoop · CarbonData · DBML (dbdiagram.io)

---

## Business Context

A national mobile operator had deployed 5G NR (New Radio) coverage across urban areas, but a significant portion of subscribers who already owned 5G-capable handsets were not actively using the 5G network — either because the NR switch was disabled on their device, or because they were unaware of the service.

The goal of this analysis was to **identify, segment, and prioritize** those subscribers for targeted commercial campaigns, enabling the network and commercial teams to:

- Quantify how many subscribers own 5G-capable terminals but have never generated 5G traffic
- Distinguish between users who have NR disabled (switch off) vs. those who have simply not accessed a 5G site
- Separate prepaid from postpaid segments, applying different eligibility thresholds for each
- Export clean, actionable subscriber lists ready for CRM campaign execution

---

## Data Sources

| Table | Description |
|-------|-------------|
| `subscriber_db.x_crm_<PERIOD>` | Full CRM subscriber base with prepaid/postpaid and SIM/USIM flags |
| `traffic_db.SDR_FLOW_SUBSCRIBER_1DAY_<PARTITION>` | Daily subscriber packet-switched traffic records with RAT, TAC, and throughput |
| `network_db.dim_terminal` | Terminal dimension: brand, model, mode and type per TAC |
| `network_db.tac_5G_terminal_n78` | Reference catalog of TAC codes supporting 5G Band N78 |
| `subscriber_db.detail_ufdr_*_<PARTITION>` | Per-application UFDR traffic records (streaming, VoIP, FTP, HTTP, IM, etc.) used for location enrichment |
| `subscriber_db.DETAIL_CDR_S1MME_<NODE_N>` | S1MME CDR records across multiple MME nodes, used to detect NR switch on/off status per device |
| `network_db.cfg_enodeb_ip` | eNodeB IP and RAN node reference |
| `network_db.dim_loc_cgisai` | Geographic dimension: department, region, urban/rural classification per cell |

---

## Pipeline Architecture

The analysis is structured in 10 sequential sections, each building on the previous stage.

```
CRM Base (millions of subscribers)
│
├── Split: PREPAID (~95%) / POSTPAID (~5%)
│
├── 5G Terminal Detection
│   └── Inner join with N78 TAC catalog → users with 5G-capable handsets
│
├── Observed 5G Traffic (RAT = 9, traffic > 1 MB)
│   └── Active 5G users identified
│
├── Legacy Traffic Summary (RAT 1/2/5/6)
│   └── Monthly traffic profile for users NOT active on 5G
│
├── Active vs Inactive Segmentation
│   ├── ACTIVE: confirmed 5G NR traffic in the period
│   └── INACTIVE: owns 5G terminal, never used NR
│
├── NR Switch Status Detection
│   └── S1MME CDR analysis across multiple MME nodes
│       ├── switch_on:  DCNR=1 observed in attach/TAU procedures
│       └── switch_off: DCNR=0 or null, no NR capability signaled
│
├── Location Enrichment
│   └── UFDR union (8 app tables) → main 4G site → department + urban flag
│
└── Final Export Segments
    ├── Postpaid inactive 5G users in urban areas
    └── Prepaid inactive 5G users in urban areas with ≥15 GB/month traffic
```

---

## Key Technical Details

**5G activity threshold:** A subscriber is considered an active 5G user only if `RAT = 9` and daily traffic exceeds 1 MB. This filters out spurious NR signaling events with no real data consumption.

**NR switch detection logic:** Derived from S1MME Attach and TAU procedures (`proc_type IN (100, 103)`). A `DCNR = 1` flag in a successful procedure indicates the terminal has NR capability enabled. The analysis aggregates across multiple MME partitions and collapses the result into a binary `switch_on / switch_off` flag per subscriber.

**Location enrichment strategy:** Because 5G-inactive users have no NR site association, location is inferred from their dominant 4G traffic site. Eight UFDR application tables are unioned, aggregated by `(msisdn, RAN_NE_ID)`, and the highest-traffic node per subscriber is selected via `ROW_NUMBER() OVER (PARTITION BY msisdn ORDER BY Total_MB DESC)`.

**Terminal deduplication:** The terminal dimension table can contain multiple rows per TAC. All joins use a `MAX()` aggregation grouped by TAC to produce a clean 1:1 terminal record before joining to traffic tables, preventing row multiplication.

**Prepaid threshold (≥15 GB/month):** Applied to prioritize heavy data users within the much larger prepaid segment, keeping the campaign list commercially viable and excluding low-engagement subscribers.

---

## Output Segments

| Segment | Criteria |
|---------|----------|
| Postpaid inactive 5G — urban | Owns N78 terminal · No observed 5G traffic · Urban area |
| Prepaid inactive 5G — urban, ≥15 GB | Owns N78 terminal · No observed 5G traffic · Urban area · ≥15 GB/month legacy traffic |

Both segments include: terminal brand/model, traffic profile, main 4G site, department, and NR switch status — structured for direct CRM campaign ingestion.

---

## Data Model

The logical data model for this pipeline is documented in [`data_model.dbml`](./data_model.dbml), compatible with [dbdiagram.io](https://dbdiagram.io) for visual rendering.

Key relationships:
- CRM base → PREPAID / POSTPAID (1:0..1 filter split)
- CRM base → daily traffic records (1:many)
- N78 terminal catalog → traffic records (capability filter)
- Terminal dimension → traffic tables (enrichment join)

---

## How to Run

> **Environment:** Apache Hive on Hadoop. Table and schema names have been generalized — substitute `<PARTITION>`, `<PERIOD>`, and `<NODE_N>` placeholders with your environment's actual values before executing.

1. Execute sections **01 → 02** to build the CRM base and terminal reference tables.
2. Execute sections **03 → 04** to classify users by 5G terminal ownership and observed 5G traffic.
3. Execute section **05** to build the legacy traffic summary for inactive users.
4. Execute section **06** to produce the active/inactive segmentation tables.
5. Execute section **07** to build the NR switch status summary (requires S1MME CDR access).
6. Execute sections **08 → 10** to enrich with location and export the final campaign segments.

Each section is self-contained and creates or replaces its own output table. Sections can be re-run individually without affecting upstream tables.

---

## Skills Demonstrated

- Large-scale SQL analytics on Hadoop/Hive (millions of subscriber records)
- Multi-source data integration: CRM, SDR traffic, terminal catalog, CDR signaling, UFDR application logs, GIS network topology
- Window functions and CTEs for complex subscriber-level aggregation
- Signaling data analysis (S1MME procedures, DCNR flag interpretation)
- Subscriber segmentation and commercial targeting logic
- Data model documentation (DBML)
- Telecom domain expertise: RAT classification, 5G N78 band, NR switch behavior, UFDR structure

---

*Author: Juan Marcelo Párraga Calizaya · [LinkedIn](https://www.linkedin.com/in/marcelo-parraga) · [GitHub](https://github.com/chelo000777)*
