# OmaDB

Does Omarchy run on this machine? A tier per model, a status per feature, the fix for each broken one,
and an honest prediction for every SKU nobody has reported yet.

| Glyph | Layer | Meaning |
|---|---|---|
| ● | Verified | ≥1 report on this exact SKU. Tier: Platinum / Gold / Silver / Bronze / Borked |
| ◐ | Predicted | No report here, but its parts are verified on other machines. Capped at Gold |
| ○ | Unverified | In the catalog, not enough part data. Own one? Report it in 60s |

The logic lives in `app/models`: `Tier` (statuses → tier), `Rating` (decay-weighted median over reports,
ProtonDB-shaped output), `ComponentEvidence` + `Prediction` (per-part, worst alternative wins).
