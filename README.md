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

## Report a machine

```bash
curl -fsSL https://omadb.technoir.cloud/report | bash
```

The script (`reporter/report.sh`) shows itself, collects DMI, CPU, PCI/USB/HDA/input IDs, kernel, Omarchy
version and channel, vainfo, fprintd and which `omarchy-hw-*` profiles match, then asks a short checklist.
It prints the exact payload and sends nothing without `y`. No serials, MACs or hostnames; machine-id is hashed.
From the live ISO it files failed installs too. Add `bash -s -- --dry-run` to see the payload only.
Device classification happens server-side in `Probe`, so a fix there fixes every past and future report.
